import { Blockchain, BlockchainSnapshot, SandboxContract, TreasuryContract } from '@ton/sandbox';
import { toNano, Dictionary, DictionaryValue, beginCell } from '@ton/core';
import {
    Collection,
    storeTep64TokenData,
    loadItemData,
    storeItemData,
    ItemData,
    storeMint,
    Mint,
    loadTep64TokenData,
} from '../wrappers/Collection';
import { JettonMaster, Tep64TokenData } from '../wrappers/JettonMaster';
import '@ton/test-utils';

// direct import
import { JettonWallet } from '../build/JettonMaster/tact_JettonWallet';
import{Item} from '../build/Collection/tact_Item';

describe('Collection', () => {
    let blockchain: Blockchain;
    let deployer: SandboxContract<TreasuryContract>;
    let collection: SandboxContract<Collection>;
    let jettonMaster: SandboxContract<JettonMaster>;
    let deployerJettonWallet: SandboxContract<JettonWallet>;
    let collectionJettonWallet: SandboxContract<JettonWallet>;
    let snapshot: BlockchainSnapshot;

    beforeAll(async () => {
        blockchain = await Blockchain.create();
        deployer = await blockchain.treasury('deployer');
        // should deploy jetton master
        {
            jettonMaster = blockchain.openContract(
                await JettonMaster.fromInit(deployer.address, {
                    $$type: 'Tep64TokenData',
                    flag: 1n,
                    content: 'https://link/',
                }),
            );
            const deployResult = await jettonMaster.send(
                deployer.getSender(),
                {
                    value: toNano('0.05'),
                },
                {
                    $$type: 'Deploy',
                    queryId: 0n,
                },
            );

            expect(deployResult.transactions).toHaveTransaction({
                from: deployer.address,
                to: jettonMaster.address,
                deploy: true,
                success: true,
            });
        }
        // should deploy collection
        {
            let catalog = Dictionary.empty(Dictionary.Keys.Uint(16), dictValueParserItemData());

            catalog.set(0, {
                $$type: 'ItemData',
                tonPrice: toNano(1n),
                jettonPrice: 2n,
                leftToMint: null,
            });

            collection = blockchain.openContract(
                await Collection.fromInit(
                    deployer.address,
                    {
                        $$type: 'Tep64TokenData',
                        flag: 1n,
                        content: 'https://link/',
                    },
                    jettonMaster.address,
                    catalog,
                    1n,
                ),
            );

            const deployResult = await collection.send(
                deployer.getSender(),
                {
                    value: toNano('0.10'),
                },
                {
                    $$type: 'Deploy',
                    queryId: 0n,
                },
            );
            expect(deployResult.transactions).toHaveTransaction({
                from: deployer.address,
                to: collection.address,
                deploy: true,
                success: true,
            });
        }

        collectionJettonWallet = blockchain.openContract(
            JettonWallet.fromAddress(await jettonMaster.getGetWalletAddress(collection.address)),
        );
        deployerJettonWallet = blockchain.openContract(
            JettonWallet.fromAddress(await jettonMaster.getGetWalletAddress(deployer.address)),
        );
        // should mint jettons
        {
            const mintResult = await jettonMaster.send(
                deployer.getSender(),
                {
                    value: toNano('1'),
                },
                {
                    $$type: 'MintJetton',
                    queryId: 0n,
                    amount: 10000n,
                    receiver: deployer.address,
                    responseDestination: deployer.address,
                    forwardAmount: 0n,
                    forwardPayload: null,
                },
            );
            expect(mintResult.events.some((event) => event.type === 'account_created')).toBe(true);
            expect((await deployerJettonWallet.getGetWalletData()).balance).toEqual(10000n);
        }

        snapshot = blockchain.snapshot();
    });

    it('should deploy', async () => {
        await blockchain.loadFrom(snapshot);
        // the check is done inside beforeEach
        // blockchain and collection are ready to use
    });

    it('should mint nft for jetton', async () => {
        await blockchain.loadFrom(snapshot);
        const mintMessage: Mint = { $$type: 'Mint', catalogItemIndex: 0n };
        const mintResult = await deployerJettonWallet.send(
            deployer.getSender(),
            {
                value: toNano('10'),
            },
            {
                $$type: 'TokenTransfer',
                queryId: 0n,
                amount: 3n,
                destination: collection.address,
                responseDestination: deployer.address,
                customPayload: null,
                forwardAmount: toNano('1.4'),
                forwardPayload: beginCell().store(storeMint(mintMessage)).endCell(),
            },
        );
        //console.log(mintResult.events.map((event) => event.type));
        expect(mintResult.events.some((event) => event.type === 'account_created')).toBe(true);
    });

    it('should return correct data', async () => {
        await blockchain.loadFrom(snapshot);
        const mintMessage: Mint = { $$type: 'Mint', catalogItemIndex: 0n };
        const mintResult = await deployerJettonWallet.send(
            deployer.getSender(),
            {
                value: toNano('10'),
            },
            {
                $$type: 'TokenTransfer',
                queryId: 0n,
                amount: 3n,
                destination: collection.address,
                responseDestination: deployer.address,
                customPayload: null,
                forwardAmount: toNano('2'),
                forwardPayload: beginCell().store(storeMint(mintMessage)).endCell(),
            },
        );
        expect(mintResult.events.some((event) => event.type === 'account_created')).toBe(true);
        let item = blockchain.openContract(Item.fromAddress((await collection.getGetNftAddressByIndex(0n))!!));
        let individualContent = (await item.getGetNftData()).individualContent;
        let index = (await item.getGetNftData()).index;
        console.log(loadTep64TokenData((await collection.getGetNftContent(index, individualContent)).asSlice()));
    });

    it('should add item', async () => {
        await blockchain.loadFrom(snapshot);
        const addResult = await collection.send(
            deployer.getSender(),
            {
                value: toNano('10'),
            },
            {
                $$type: 'ChangeItemData',
                catalogIndex: 4n,
                itemData: {
                    $$type: 'ItemData',
                    tonPrice: 1n,
                    jettonPrice: 10n,
                    leftToMint: 10n,
                },
            },
        );
        expect(addResult.transactions).toHaveTransaction({
            from: deployer.address,
            to: collection.address,
            success: true,
        });
        const mintMessage: Mint = { $$type: 'Mint', catalogItemIndex: 4n };
        const mintResult = await deployerJettonWallet.send(
            deployer.getSender(),
            {
                value: toNano('10'),
            },
            {
                $$type: 'TokenTransfer',
                queryId: 0n,
                amount: 11n,
                destination: collection.address,
                responseDestination: deployer.address,
                customPayload: null,
                forwardAmount: toNano('1.4'),
                forwardPayload: beginCell().store(storeMint(mintMessage)).endCell(),
            },
        );
        expect(mintResult.events.some((event) => event.type === 'account_created')).toBe(true);
    });
});

function dictValueParserItemData(): DictionaryValue<ItemData> {
    return {
        serialize: (src, builder) => {
            builder.storeRef(beginCell().store(storeItemData(src)).endCell());
        },
        parse: (src) => {
            return loadItemData(src.loadRef().beginParse());
        },
    };
}