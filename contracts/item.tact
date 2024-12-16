import "./models/messages.tact";
import "./models/consts.tact";

contract Item {
    collection: Address;
    itemIndex: Int;
    isInitialized: Bool;
    owner: Address;
    individualContent: Cell;

    //----------- Init -----------//

    init(collection: Address, index: Int){
        require(sender() == collection, "unauthorized");
        self.isInitialized = false;
        self.owner = sender();
        self.individualContent = emptyCell();
        self.itemIndex = index;
        self.collection = collection;
    }

    //----------- Receivers -----------//

    receive(msg: ItemTransfer){
        let ctx: Context = context();
        require(ctx.value >= msg.forwardAmount + GAS_CONSUMPTION + TRANSACTION_FEE, "inflow value not sufficient"); // WE SHOULD ALSO TAKE INTO ACCOUNT TONS FOR STORAGE
        require(ctx.sender == self.owner, "unauthorized");
        let prevOwner = self.owner;
        self.owner = msg.newOwner;
        
        if (self.isInitialized == false) {
            // only the collection contract can initialize the NFT
            require(ctx.sender == self.collection, "unauthorized");
            require(msg.customPayload != null, "nft custom payload invalid");
            self.individualContent = msg.customPayload!!;
            self.isInitialized = true;
        }

        nativeReserve(MIN_TONS_FOR_STORAGE, ReserveExact);

        if (msg.forwardAmount > 0) {
            send(SendParameters{
                    to: msg.responseDestination,
                    value: msg.forwardAmount,
                    bounce: false,
                    body: OwnershipAssigned{
                        queryId: msg.queryId,
                        prevOwner: prevOwner,
                        forwardPayload: msg.forwardPayload
                    }.toCell()
                }
            );
        }
        
        send(SendParameters{
                to: msg.responseDestination,
                value: 0,
                mode: SendRemainingBalance,
                bounce: false,
                body: Excesses{queryId: msg.queryId}.toCell()
            }
        );
    }

    receive(msg: GetStaticData){
        let ctx: Context = context();
        nativeReserve(MIN_TONS_FOR_STORAGE, ReserveExact);
        send(SendParameters{
                to: ctx.sender,
                value: 0,
                mode: SendRemainingBalance,
                bounce: true,
                body: ReportStaticData{
                    queryId: msg.queryId,
                    index: self.itemIndex,
                    collection: self.collection
                }.toCell()
            }
        );
    }

    //----------- Getters -----------//

    get fun get_nft_data(): GetNftData {
        return
            GetNftData{
                init: self.isInitialized,
                index: self.itemIndex,
                collectionAddress: self.collection,
                ownerAddress: self.owner,
                individualContent: self.individualContent
            };
    }
}