import { task } from "hardhat/config";
import { getBtcHeaders, getContractAddress } from "../scripts/utils";

task(`setGenesis`, `Sets genesis epoch for BTC relay`)
    .addParam(`height`, `The height of the genesis epoch block`)
    .addParam(`prooflength`, `The proof length for the BTC relay`)
    .setAction(async (taskArgs, hre) => {
        const height = Number(taskArgs.height);
        const prooflength = Number(taskArgs.prooflength);

        const factory = await hre.ethers.getContractFactory(`BTCRelay`);
        const btcRelayAddress = getContractAddress(`BTCRelay`);
        console.log(btcRelayAddress);
        const btcRelay = factory.attach(btcRelayAddress);

        const genesisHeader = await getBtcHeaders(height);
        await btcRelay.genesis(genesisHeader, height, prooflength);
    });

task(`retarget`, `Sets next epoch difficulty for BTC relay`).setAction(async (_, hre) => {
    const factory = await hre.ethers.getContractFactory(`BTCRelay`);
    const btcRelayAddress = getContractAddress(`BTCRelay`);
    const btcRelay = factory.attach(btcRelayAddress);

    const relayRange = await btcRelay.getRelayRange();
    const retargetHeight = relayRange.currentEpochEnd.toNumber() + 1;
    const proofLength = (await btcRelay.proofLength()).toNumber();

    const retargetHeaders = await getBtcHeaders(retargetHeight, proofLength);
    await btcRelay.retarget(retargetHeaders);
});

task(`getbtcdiff`, `Gets current BTC difficulty from BTC relay`).setAction(async (_, hre) => {
    const factory = await hre.ethers.getContractFactory(`BTCRelay`);
    const btcRelayAddress = getContractAddress(`BTCRelay`);
    const btcRelay = factory.attach(btcRelayAddress);

    const currDiff = await btcRelay.getCurrentEpochDifficulty();
    console.log(currDiff.toString());
});
