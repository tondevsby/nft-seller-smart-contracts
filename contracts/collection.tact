import "./models/messages.tact";
import "./models/consts.tact";
import "./item.tact";
import "@stdlib/deploy";


contract Collection with Deployable{ 
    nextItemIndex: Int as uint32 = 0; 
    owner: Address;
    collectionContent: Tep64TokenData;
    jettonMaster: Address;
    jettonWallet: Address;
    catalog: map<Int as uint16, ItemData>; // index -> ItemData
    catalogSize: Int as uint8;
    

    //----------- Init -----------//

    init(owner: Address, collectionContent: Tep64TokenData, jettonMaster: Address, catalog: map<Int as uint16, ItemData>, catalogSize: Int){
        require(catalogSize <= MAX_CATALOG_SIZE, "Too large catalog");

        self.owner = owner;
        self.collectionContent = collectionContent;
        self.jettonMaster = jettonMaster;
        self.jettonWallet = jettonMaster;
        self.catalog = catalog;
        self.catalogSize = catalogSize;

        send(SendParameters{
            to: self.jettonMaster,
            value: 0,
            mode: SendRemainingValue, 
            body: ProvideWalletAddress{
                queryId: now(), 
                ownerAddress: myAddress(), 
                includeAddress: false
            }.toCell()
        });
    }


    //----------- Receivers -----------//

    receive("withdraw") {
        require(sender() == self.owner, "unauthorized");
        nativeReserve(MIN_TONS_FOR_STORAGE, ReserveExact);
        send(SendParameters{
            to: sender(),
            value: myBalance() - (MIN_TONS_FOR_STORAGE + GAS_CONSUMPTION),
            mode: SendRemainingBalance,
            body: "Here comes the money".asComment()
        })
    }


    receive(msg: ChangeItemData){
        require(sender() == self.owner, "unauthorized");
        if (msg.itemData != null) {
            if (self.catalog.get(msg.catalogIndex) == null) {
                require(self.catalogSize <= MAX_CATALOG_SIZE, "catalog size reaches the limit");
                self.catalogSize += 1;
            }
        } else {
            if (self.catalog.get(msg.catalogIndex) != null) {
                self.catalogSize -= 1;
            }
        }

        self.catalog.set(msg.catalogIndex, msg.itemData);
    }

    receive(msg: TakeWalletAddress){
        require(sender() == self.jettonWallet, "unauthorized");
        self.jettonWallet = msg.walletAddress;
    }

    receive(msg: TransferNotification){
        require(sender() == self.jettonWallet, "unauthorized");
        let mintMsgSlice: Cell = msg.forwardPayload!!;
        let mintMsg: Mint = Mint.fromCell(mintMsgSlice);
        let catalogItemIndex = mintMsg.catalogItemIndex;
        let itemData: ItemData? = self.catalog.get(catalogItemIndex);

        // Token refund if needed
        if (itemData == null || msg.amount < (itemData!!).jettonPrice || context().value < PROCESSING_VALUE || ((itemData!!).leftToMint != null && (itemData!!).leftToMint!! == 0)) {
            send(SendParameters{
                to: sender(), 
                value: 0,
                mode: SendRemainingValue, 
                bounce: false,
                body: TokenTransfer{
                    queryId: msg.queryId,
                    amount: msg.amount,
                    destination: msg.sender,
                    responseDestination: msg.sender,
                    customPayload: null,
                    forwardAmount: 0,
                    forwardPayload: null,
                }.toCell(),
            });
            return;
        }

        self.mint(msg.sender, PROCESSING_VALUE, catalogItemIndex, itemData);
    }

    receive(msg: Mint){
        let catalogItemIndex = msg.catalogItemIndex;
        let itemData: ItemData? = self.catalog.get(catalogItemIndex);
        require(itemData != null, "unknown catalog index");
        require(context().value >= itemData!!.tonPrice, "infow value not sufficient");
        if ((itemData!!).leftToMint != null){
            require((itemData!!).leftToMint!! > 0, "minting ended");
        }

        self.mint(sender(), PROCESSING_VALUE, catalogItemIndex, itemData);
    }

    bounced(msg: bounced<ItemTransfer>) {
        self.nextItemIndex -= 1;
    }


    //----------- Getters -----------//

    get fun get_collection_data(): CollectionData {
        return CollectionData{
                    nextItemIndex: self.nextItemIndex,
                    collectionContent: Tep64TokenData{
                        flag: self.collectionContent.flag,
                        content: beginString()
                            .concat(self.collectionContent.content)
                            .concat("meta.json")
                            .toString()
                    }.toCell(),
                    ownerAddress: self.owner,
                };
    }

    get fun get_nft_address_by_index(index: Int): Address? {
        require(index < self.nextItemIndex && index >= 0, "nft index not exists");
        let initCode: StateInit = self.getNftItemInit(index);
        return contractAddress(initCode);
    }

    get fun get_nft_content(index: Int, individualContent: Cell): Cell {
     return Tep64TokenData{
                flag: 1,
                content: beginString()
                    .concat(self.collectionContent.content)
                    .concat(individualContent.asSlice().asString())
                    .concat("meta.json")
                    .toString(),
            }.toCell();
    }


    //----------- Private methods -----------//

    fun mint(sender: Address, msgValue: Int, catalogIndex: Int, itemData: ItemData?) {
        require(self.nextItemIndex >= 0, "non sequential nft");
        let nftInit: StateInit = self.getNftItemInit(self.nextItemIndex);
        
        send(SendParameters {
            to: contractAddress(nftInit), 
            value: msgValue, bounce: false, 
            mode: SendIgnoreErrors, 
            body: ItemTransfer {
                queryId: 0,
                newOwner: sender,
                responseDestination: self.owner,
                customPayload: beginString()
                .concat(catalogIndex.toString())
                .concat("/")
                .toCell(), 
                forwardAmount: 0, 
                forwardPayload: null 
            }.toCell(),
            code: nftInit.code, 
            data: nftInit.data
        });
     
        self.nextItemIndex += 1;

        // decrease available amount
        if ((itemData!!).leftToMint != null){
            self.catalog.set(catalogIndex, ItemData{
                tonPrice: (itemData!!).tonPrice,
                jettonPrice: (itemData!!).jettonPrice,
                leftToMint: (itemData!!).leftToMint!! - 1,
            });
        }

        // emit(LogEventMintRecord{minter: msg.sender, item_id: self.nextItemIndex, generate_number: nativeRandom()}.toCell());
    }


    fun getNftItemInit(item_index: Int): StateInit {
        return initOf Item(myAddress(), item_index);
    }
}