import "@stdlib/deploy";
import "./jetton_wallet.tact";
import "./models/messages.tact";


contract JettonMaster with Deployable {
    owner: Address;
    content: Cell;
    totalSupply: Int as coins;
    mintable: Bool;


    //----------- Init -----------//

    init(owner: Address, content: Tep64TokenData){
        self.owner = owner;
        self.content = content.toCell();
        self.totalSupply = 0;
        self.mintable = true;
    }


    //----------- Receivers -----------//

    receive(msg: MintJetton){
        let ctx: Context = context();
        require(ctx.sender == self.owner, "unathorized");
        require(self.mintable, "not mintable");
        require(msg.amount > 0, "amount should be positive");
        require(ctx.value >= msg.forwardAmount, "inflow value not sufficient");
        self.totalSupply += msg.amount;
        let jettonWallet = self.getJettonWalletContract(msg.receiver);
        
        // deploy the wallet if it's not deployed yet,
        // then send the minted tokens to the wallet.
        nativeReserve(MIN_TONS_FOR_STORAGE, ReserveExact);
        send(SendParameters{
                to: contractAddress(jettonWallet),
                value: 0,
                bounce: false,
                mode: SendRemainingBalance,
                body: TokenTransferInternal{
                    queryId: msg.queryId,
                    amount: msg.amount,
                    from: sender(),
                    responseDestination: msg.responseDestination,
                    forwardAmount: msg.forwardAmount,
                    forwardPayload: msg.forwardPayload
                }.toCell(),
                code: jettonWallet.code,
                data: jettonWallet.data
            }
        );
    }

    receive(msg: TokenBurnNotification){
        let ctx: Context = context();
        require(self.totalSupply >= msg.amount, "jetton balance insufficient");
        let walletAddr = self.get_wallet_address(msg.sender);
        require(sender() == walletAddr, "unauthorized");
        self.totalSupply -= msg.amount;
        
        // refund the excess TON to the sender.
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

    receive(msg: ProvideWalletAddress){
        let walletAddr = self.get_wallet_address(msg.ownerAddress);
        
        nativeReserve(MIN_TONS_FOR_STORAGE, ReserveExact);
        send(SendParameters{
                to: sender(),
                value: 0,
                bounce: false,
                mode: SendRemainingBalance,
                body: TakeWalletAddress{
                    queryId: msg.queryId,
                    walletAddress: walletAddr
                    // ownerAddress: msg.includeAddress ? msg.ownerAddress : null,
                }.toCell()
            }
        );
    }


    //----------- Getters -----------//

    get fun get_jetton_data(): JettonMasterData {
        return
            JettonMasterData{
                totalSupply: self.totalSupply,
                mintable: self.mintable,
                owner: self.owner,
                content: self.content,
                walletCode: self.getJettonWalletContract(myAddress()).code
            };
    }

    get fun get_wallet_address(owner: Address): Address {
        return self.getWalletAddress(owner);
    }


    //----------- Private methods -----------//

    fun getWalletAddress(owner: Address): Address {
        return contractAddress(self.getJettonWalletContract(owner));
    }

    fun getJettonWalletContract(owner: Address): StateInit {
        return initOf JettonWallet(myAddress(), owner);
    }
}