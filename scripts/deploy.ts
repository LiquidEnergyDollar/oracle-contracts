import hre from "hardhat";

import { chainIds, VERBOSE, ZK_EVM } from "../hardhat.config";
import {
    BTCRelay,
    BTCRelay__factory,
    LEDOracle,
    LEDOracle__factory,
    PriceFeed,
    PriceFeed__factory,
} from "../types";
import { deployWait } from "./utils";
import { GasOptions } from "./types";
import { Wallet } from "ethers";

import { Deployer as zkDeployer } from "@matterlabs/hardhat-zksync-deploy";

// --- Helper functions for deploying contracts ---

// Also adds them to hardhat-tracer nameTags, which gives them a trackable name
// for events when `npx hardhat test --logs` is used.

// deployBTCRelay deploys the BTCRelay contract.
export async function deployBTCRelay(wallet: Wallet, gasOpts?: GasOptions): Promise<BTCRelay> {
    let btcRelayContract: BTCRelay;
    if (await isZkDeployment(wallet)) {
        const deployer = zkDeployer.fromEthWallet(hre, wallet);
        const zkArtifact = await deployer.loadArtifact(`BTCRelay`);
        btcRelayContract = (await deployWait(
            deployer.deploy(zkArtifact, [], {
                maxFeePerGas: gasOpts?.maxFeePerGas,
                maxPriorityFeePerGas: gasOpts?.maxPriorityFeePerGas,
                gasLimit: gasOpts?.gasLimit,
            }),
        )) as BTCRelay;
    } else {
        const btcRelay: BTCRelay__factory = await hre.ethers.getContractFactory(`BTCRelay`, wallet);
        btcRelayContract = await deployWait(
            btcRelay.deploy({
                //maxFeePerGas: gasOpts?.maxFeePerGas,
                //maxPriorityFeePerGas: gasOpts?.maxPriorityFeePerGas,
                gasLimit: gasOpts?.gasLimit,
            }),
        );
    }

    if (VERBOSE) console.log(`BTCRelay: ${btcRelayContract.address}`);
    hre.tracer.nameTags[btcRelayContract.address] = `BTCRelay`;

    return btcRelayContract;
}

// deployPriceFeed deploys the PriceFeed contract.
export async function deployPriceFeed(
    btcContract: string,
    ethContract: string,
    wallet: Wallet,
    gasOpts?: GasOptions,
): Promise<PriceFeed> {
    let priceFeedContract: PriceFeed;
    if (await isZkDeployment(wallet)) {
        const deployer = zkDeployer.fromEthWallet(hre, wallet);
        const zkArtifact = await deployer.loadArtifact(`PriceFeed`);
        priceFeedContract = (await deployWait(
            deployer.deploy(zkArtifact, [btcContract, ethContract], {
                maxFeePerGas: gasOpts?.maxFeePerGas,
                maxPriorityFeePerGas: gasOpts?.maxPriorityFeePerGas,
                gasLimit: gasOpts?.gasLimit,
            }),
        )) as PriceFeed;
    } else {
        const priceFeed: PriceFeed__factory = await hre.ethers.getContractFactory(
            `PriceFeed`,
            wallet,
        );
        priceFeedContract = await deployWait(
            priceFeed.deploy(btcContract, ethContract, {
                //maxFeePerGas: gasOpts?.maxFeePerGas,
                //maxPriorityFeePerGas: gasOpts?.maxPriorityFeePerGas,
                gasLimit: gasOpts?.gasLimit,
            }),
        );
    }

    if (VERBOSE) console.log(`PriceFeed: ${priceFeedContract.address}`);
    hre.tracer.nameTags[priceFeedContract.address] = `PriceFeed`;

    return priceFeedContract;
}

// deployLEDOracle deploys the PriceFeed contract.
export async function deployLEDOracle(
    priceFeedOracle: string,
    bitcoinOracle: string,
    diffSeedValue: string,
    diffSmoothingFactor: string,
    priceSeedValue: string,
    priceSmoothingFactor: string,
    initScaleFactor: string,
    initKoomeyTimeInSeconds: string,
    wallet: Wallet,
    gasOpts?: GasOptions,
): Promise<LEDOracle> {
    let ledOracleContract: LEDOracle;
    if (await isZkDeployment(wallet)) {
        const deployer = zkDeployer.fromEthWallet(hre, wallet);
        const zkArtifact = await deployer.loadArtifact(`PriceFeed`);
        ledOracleContract = (await deployWait(
            deployer.deploy(
                zkArtifact,
                [
                    priceFeedOracle,
                    bitcoinOracle,
                    diffSeedValue,
                    diffSmoothingFactor,
                    priceSeedValue,
                    priceSmoothingFactor,
                    initScaleFactor,
                    initKoomeyTimeInSeconds,
                ],
                {
                    maxFeePerGas: gasOpts?.maxFeePerGas,
                    maxPriorityFeePerGas: gasOpts?.maxPriorityFeePerGas,
                    gasLimit: gasOpts?.gasLimit,
                },
            ),
        )) as LEDOracle;
    } else {
        const ledOracle: LEDOracle__factory = await hre.ethers.getContractFactory(
            `LEDOracle`,
            wallet,
        );
        ledOracleContract = await deployWait(
            ledOracle.deploy(
                priceFeedOracle,
                bitcoinOracle,
                diffSeedValue,
                diffSmoothingFactor,
                priceSeedValue,
                priceSmoothingFactor,
                initScaleFactor,
                initKoomeyTimeInSeconds,
                {
                    //maxFeePerGas: gasOpts?.maxFeePerGas,
                    //maxPriorityFeePerGas: gasOpts?.maxPriorityFeePerGas,
                    gasLimit: gasOpts?.gasLimit,
                },
            ),
        );
    }

    if (VERBOSE) console.log(`LEDOracle: ${ledOracleContract.address}`);
    hre.tracer.nameTags[ledOracleContract.address] = `LEDOracle`;

    return ledOracleContract;
}

// isZkDeployment returns if ZK_EVM is true and the network is a supported zk rollup.
async function isZkDeployment(wallet: Wallet): Promise<boolean> {
    const net = await wallet.provider.getNetwork();
    return (
        ZK_EVM &&
        (net.chainId === chainIds[`zksync-mainnet`] || net.chainId === chainIds[`zksync-goerli`])
    );
}
