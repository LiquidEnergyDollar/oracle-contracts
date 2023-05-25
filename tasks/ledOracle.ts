import { task } from "hardhat/config";
import { getContractAddress } from "../scripts/utils";

task(`getledpereth`, `Gets current USD per LED and emits event`).setAction(async (_, hre) => {
    const network = String(hre.network.name);
    const factory = await hre.ethers.getContractFactory(`LEDOracle`);
    const ledOracleAddress = getContractAddress(`LEDOracle`, network);
    const ledOracle = factory.attach(ledOracleAddress);

    const tx = await ledOracle.getUSDPerLED();
    const rc = await tx.wait();
    const event = rc.events?.find(event => event.event === `LEDOracleUpdated`);
    console.log(JSON.stringify(event));
});
