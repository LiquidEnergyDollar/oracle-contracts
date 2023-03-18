import { task } from "hardhat/config";
import { getContractAddress } from "../scripts/utils";

task(`getledpereth`, `Gets current LED per ETH and emits event`).setAction(async (_, hre) => {
    const factory = await hre.ethers.getContractFactory(`LEDOracle`);
    const ledOracleAddress = getContractAddress(`LEDOracle`);
    const ledOracle = factory.attach(ledOracleAddress);

    const currPrice = await ledOracle.getlEDPerEth();
    console.log(currPrice.toString());
});
