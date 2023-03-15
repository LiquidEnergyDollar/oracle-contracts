import { expect } from "chai";
import { ethers } from "hardhat";
import { getBtcHeaders } from "../scripts/utils";
import { BTCRelay } from "../types";

describe("BTC Relay", async () => {
    let btcRelay: BTCRelay;

    beforeEach(async () => {
        const factory = await ethers.getContractFactory("BTCRelay");
        btcRelay = await factory.deploy();
    });

    it("behave correctly when setting genesis and retargeting", async () => {
        const proofLength = 2;
        const height = 552384;

        const genesisHeader = await getBtcHeaders(height);
        await btcRelay.genesis(genesisHeader, height, proofLength);

        expect(await btcRelay.getCurrentEpochDifficulty()).to.equal(5646403851534);

        const retargetHeader = await getBtcHeaders(554400, proofLength);
        await btcRelay.retarget(retargetHeader);

        expect(await btcRelay.getPrevEpochDifficulty()).to.equal(5646403851534);
        expect(await btcRelay.getCurrentEpochDifficulty()).to.equal(5106422924659);
    });
});
