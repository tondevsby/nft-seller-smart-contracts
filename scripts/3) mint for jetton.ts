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
import { COLLECTION_ADDRESS, MY_JETTON_WALLET } from './consts';

export async function run(provider: NetworkProvider) {
    const wallet = provider.provider(MY_JETTON_WALLET);
    const message: MintForJetton = {
        queryId: 0n,
        amount: 2000000n,
        destination: COLLECTION_ADDRESS,
        responseDestination: provider.sender().address!!,
        forwardAmount: toNano('0.11'),
        catalogItemIndex: 0n,
    };
    return await wallet.internal(provider.sender(), {
        value: toNano('0.14'),
        bounce: null,
        sendMode: SendMode.PAY_GAS_SEPARATELY,
        body: storeMintForJetton(message),
    });
}
type MintForJetton = {
    queryId: bigint;
    amount: bigint;
    destination: Address;
    responseDestination: Address;
    forwardAmount: bigint;
    catalogItemIndex: bigint;
};
const storeMintForJetton = (src: MintForJetton) =>
    beginCell()
        .storeUint(260734629, 32)
        .storeUint(src.queryId, 64)
        .storeCoins(src.amount)
        .storeAddress(src.destination)
        .storeAddress(src.responseDestination)
        .storeBit(false)
        .storeCoins(src.forwardAmount)
        .storeBit(true)
        .storeRef(beginCell().storeUint(977977286, 32).storeUint(src.catalogItemIndex, 16).endCell())
        .endCell();
        