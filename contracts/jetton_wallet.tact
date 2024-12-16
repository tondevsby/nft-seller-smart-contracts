import "./models/messages.tact";
import "./models/consts.tact";


contract JettonWallet {
    owner: Address;
    master: Address;
    balance: Int as coins;


    //----------- Init -----------//

    init(master: Address, owner: Address){
        self.master = master;
        self.owner = owner;
        self.balance = 0;
    }


    //----------- Receivers -----------//

    receive(msg: TokenTransfer){
        let ctx: Context = context();
        require(ctx.sender == self.owner, "unauthorized");
        require(self.balance >= msg.amount, "unauthorized");
        require(msg.amount > 0, "amount should be positive");
        require(ctx.value >= msg.forwardAmount, "inflow value not sufficient");
        self.balance -= msg.amount;
        let destJettonContract = self.getJettonWalletContract(msg.destination);
        nativeReserve(MIN_TONS_FOR_STORAGE, ReserveExact);
        send(SendParameters{
                to: contractAddress(destJettonContract),
                value: 0,
                mode: SendRemainingBalance,
                bounce: true,
                body: TokenTransferInternal{
                    queryId: msg.queryId,
                    amount: msg.amount,
                    from: self.owner,
                    responseDestination: msg.responseDestination,
                    forwardAmount: msg.forwardAmount,
                    forwardPayload: msg.forwardPayload
                }.toCell(),
                code: destJettonContract.code,
                data: destJettonContract.data
            }
        );
    }

    // this is unspecified by standard, but suggested format of internal message.
    // receive tokens from another jetton wallet
    receive(msg: TokenTransferInternal){
        let ctx: Context = context();
        require(msg.amount > 0, "amount should be positive");
        require(ctx.value > msg.forwardAmount, "inflow value not sufficient");
        // only the owner or another jetton wallet can send TokenTransferInternal
        if (ctx.sender != self.master) {
            let peerJettonContractAddr = contractAddress(self.getJettonWalletContract(msg.from));
            require(ctx.sender == peerJettonContractAddr, "unauthorized");
        }
        self.balance += msg.amount;
        if (msg.forwardAmount > 0) {
            send(SendParameters{
                    to: self.owner,
                    value: msg.forwardAmount,
                    bounce: false,
                    // mode: SendIgnoreErrors,
                    body: TransferNotification{
                        queryId: msg.queryId,
                        amount: msg.amount,
                        sender: msg.from,
                        forwardPayload: msg.forwardPayload
                    }.toCell()
                }
            );
        }
        nativeReserve(MIN_TONS_FOR_STORAGE, ReserveExact);
        send(SendParameters{
                to: msg.responseDestination,
                value: 0,
                bounce: false,
                mode: SendRemainingBalance,
                body: Excesses{queryId: msg.queryId}.toCell()
            }
        );
    }

    receive(msg: Burn){
        let ctx: Context = context();
        require(ctx.sender == self.owner, "unauthorized");
        require(self.balance == msg.amount, "balance not sufficient");
        require(msg.amount > 0, "amount should be positive");
        // Update balance
        self.balance -= msg.amount;
        // notify master to update totalSupply
        nativeReserve(MIN_TONS_FOR_STORAGE, ReserveExact);
        send(SendParameters{
                to: self.master,
                value: 0,
                mode: SendRemainingBalance,
                bounce: true,
                body: TokenBurnNotification{
                    queryId: msg.queryId,
                    amount: msg.amount,
                    sender: self.owner,
                    responseDestination: msg.responseDestination
                }.toCell()
            }
        );
    }


    //----------- Getters -----------//

    // this is a TEP-074 standard getter method
    get fun get_wallet_data(): JettonWalletData {
        return
            JettonWalletData{
                balance: self.balance,
                owner: self.owner,
                master: self.master,
                walletCode: self.getJettonWalletContract(self.owner).code
            };
    }

    bounced(src: bounced<TokenTransferInternal>){
        self.balance += src.amount;
    }

    bounced(src: bounced<TokenBurnNotification>){
        self.balance += src.amount;
    }


    //----------- Private methods -----------//

    fun getJettonWalletContract(owner: Address): StateInit {
        return initOf JettonWallet(self.master, owner);
    }
}