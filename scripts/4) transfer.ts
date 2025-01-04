import {
    Address,
    beginCell,
    toNano,
    Cell,
    Contract,
    ContractProvider,
    Sender,
    SendMode,
    Slice,
    Builder,
} from '@ton/core';
import { NetworkProvider } from '@ton/blueprint';
import { COLLECTION_ADDRESS, NFT_ITEM } from './consts';

export async function run(provider: NetworkProvider) {
    const wallet = provider.provider(NFT_ITEM);
    const message: Transfer = {
        queryId: 0n,
        newOwner: COLLECTION_ADDRESS,
        responseDestination: provider.sender().address!!,
        customPayload: null,
        forwardAmount: toNano('0.001'),
        forwardPayload: null,
    };
    return await wallet.internal(provider.sender(), {
        value: toNano('0.03'),
        bounce: null,
        sendMode: SendMode.PAY_GAS_SEPARATELY,
        body: storeTransfer(message),
    });
}

export type Transfer = {
    queryId: bigint;
    newOwner: Address;
    responseDestination: Address;
    customPayload: Cell | null;
    forwardAmount: bigint;
    forwardPayload: Cell | null;
};

export function storeTransfer(src: Transfer): Cell {
    let b_0 = beginCell();
    b_0.storeUint(1607220500, 32);
    b_0.storeUint(src.queryId, 64);
    b_0.storeAddress(src.newOwner);
    b_0.storeAddress(src.responseDestination);
    if (src.customPayload !== null && src.customPayload !== undefined) {
        b_0.storeBit(true).storeRef(src.customPayload);
    } else {
        b_0.storeBit(false);
    }
    b_0.storeCoins(src.forwardAmount);
    if (src.forwardPayload !== null && src.forwardPayload !== undefined) {
        b_0.storeBit(true).storeRef(src.forwardPayload);
    } else {
        b_0.storeBit(false);
    }
    return b_0.endCell();
}
