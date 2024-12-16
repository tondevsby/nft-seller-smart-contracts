import { toNano } from '@ton/core';
import { Collection } from '../wrappers/Collection';
import { NetworkProvider } from '@ton/blueprint';

export async function run(provider: NetworkProvider) {
    const collection = provider.open(await Collection.fromInit());

    await collection.send(
        provider.sender(),
        {
            value: toNano('0.05'),
        },
        {
            $$type: 'Deploy',
            queryId: 0n,
        }
    );

    await provider.waitForDeploy(collection.address);

    // run methods on `collection`
}
