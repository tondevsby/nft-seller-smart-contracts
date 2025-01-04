import { toNano } from '@ton/core';
import { Collection, Mint } from '../wrappers/Collection';
import { NetworkProvider } from '@ton/blueprint';
import { COLLECTION_ADDRESS } from './consts';
import {} from '../build/Collection/tact_Item';

export async function run(provider: NetworkProvider) {
    const collectionContract = provider.open(Collection.fromAddress(COLLECTION_ADDRESS));
    const mintMessage: Mint = { $$type: 'Mint', catalogItemIndex: 0n };
    return await collectionContract.send(
        provider.sender(),
        {
            value: toNano('0.5'),
        },
        mintMessage,
    );
}
