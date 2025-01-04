import { beginCell, Dictionary, DictionaryValue, toNano } from '@ton/core';
import { Collection, ItemData, loadItemData, storeItemData, Tep64TokenData } from '../wrappers/Collection';
import { NetworkProvider } from '@ton/blueprint';
import { BASE_URL, TESTNET_USDT_MASTER } from './consts';
import {} from '../build/Collection/tact_Item';

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

export async function run(provider: NetworkProvider) {
    const collectionContent: Tep64TokenData = {
        $$type: 'Tep64TokenData',
        flag: 1n, // OFFCHAIN FLAG
        content: BASE_URL,
    };
    let catalog = Dictionary.empty(Dictionary.Keys.Uint(16), dictValueParserItemData());

    // item with catalog_index 0 will cost 0.33 ton or 2 usdt
    catalog.set(0 /*catalog index*/, {
        $$type: 'ItemData',
        tonPrice: toNano('0.33'),
        jettonPrice: 2000000n,
        leftToMint: 300n,
    });
    catalog.set(1 /*catalog index*/, {
        $$type: 'ItemData',
        tonPrice: toNano('0.66'),
        jettonPrice: 4000000n,
        leftToMint: 100n,
    });
    catalog.set(2 /*catalog index*/, {
        $$type: 'ItemData',
        tonPrice: toNano('1.2'),
        jettonPrice: 8000000n,
        leftToMint: 50n,
    });
    const collection = provider.open(
        await Collection.fromInit(provider.sender().address!!, collectionContent, TESTNET_USDT_MASTER, catalog, 3n),
    );
    const deployResult = await collection.send(
        provider.sender(),
        {
            value: toNano('0.3'),
        },
        {
            $$type: 'Deploy',
            queryId: 0n,
        },
    );
    await provider.waitForDeploy(collection.address);
    console.log(deployResult);
}
