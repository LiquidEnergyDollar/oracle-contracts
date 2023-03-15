import { expect } from "chai";
import { BaseContract, ContractReceipt, ContractTransaction, utils } from "ethers";
import { Interface } from "ethers/lib/utils";
import * as rm from "typed-rest-client";

import { TransactionReceipt } from "@ethersproject/providers";
import { GAS_MODE } from "../hardhat.config";
import * as deploymentsJson from "../deployments.json";

// --- Transaction & contract deployment helpers ---

// Wait for a contract to be deployed.
export async function deployWait<T extends BaseContract>(contractPromise: Promise<T>): Promise<T> {
    const contract = await contractPromise;
    await contract.deployed();
    return contract;
}

// Submit a transaction and wait for it to be mined. Then assert that it succeeded.
export async function submitTxWait(
    tx: Promise<ContractTransaction>,
    txName = `transaction`,
): Promise<ContractReceipt> {
    void expect(tx).to.not.be.reverted;
    const receipt = await (await tx).wait();
    if (GAS_MODE) {
        console.log(`Gas used for ` + txName + `: ` + receipt.gasUsed.toString());
    }
    expect(receipt.status).to.eq(1);
    return receipt;
}

// Submit a transaction and expect it to fail. Throws an error if it succeeds.
export async function submitTxFail(
    tx: Promise<ContractTransaction>,
    expectedCause?: string,
): Promise<void> {
    const receipt = tx.then(result => result.wait());
    await expectTxFail(receipt, expectedCause);
}

// Expect a transaction to fail. Throws an error if it succeeds.
export async function expectTxFail<T>(tx: Promise<T>, expectedCause?: string): Promise<void> {
    try {
        await tx;
    } catch (error) {
        if (expectedCause) {
            if (!(error instanceof Error)) {
                throw error;
            }

            // error cleaning
            let cause = error.message.replace(
                `VM Exception while processing transaction: reverted with reason string `,
                ``,
            );
            // custom error specific
            cause = cause.replace(
                `VM Exception while processing transaction: reverted with custom error `,
                ``,
            );
            // custom error specific, e.g. 'MsgNeedsAddr()' error to check for just 'MsgNeedsAddr'
            cause = cause.replace(`()`, ``);
            expect(cause).to.equal(
                `'` + expectedCause + `'`,
                `tx failed as expected, but unexpected reason string`,
            );
        }
        return;
    }
    expect.fail(`expected tx to fail, but it succeeded`);
}

export function parseEvent(
    receipt: TransactionReceipt,
    contractInterface: Interface,
): utils.LogDescription[] {
    const res: utils.LogDescription[] = [];
    for (const log of receipt.logs) {
        let result;
        try {
            result = contractInterface.parseLog(log);
            res.push(result);
        } catch (e) {
            continue;
        }
    }
    return res;
}

interface BTCResult {
    // Need to use "any" here since return values are keyed off block height
    // (which we don't know ahead of time)
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    data: any;
}

export const getBtcHeaders = async (height: number, proofLength?: number): Promise<string> => {
    const urlString = `/bitcoin/raw/block/`;
    const host = `https://api.blockchair.com`;
    const rest = new rm.RestClient(`btc-relay`, host);

    // Proof length can be optional when we just want one block
    // E.g. when setting genesis
    let lower: number;
    let upper: number;
    if (proofLength) {
        lower = height - proofLength;
        upper = height + proofLength;
    } else {
        lower = height;
        upper = height + 1;
    }

    let header = `0x`;
    try {
        for (let i = lower; i < upper; i++) {
            console.log(`Retrieving header for block ${i}`);
            const res = await rest.get<BTCResult>(urlString + i.toString());
            header = header.concat(res.result?.data[i].raw_block.slice(0, 160));
        }
        return header;
    } catch (err) {
        console.log(`Error encountered while attempting to retrieve block headers`);
        throw err;
    }
};

export const getContractAddress = (contractName: string): string => {
    for (const deployment of deploymentsJson.deployments) {
        // Default to optimism deployments
        if (deployment.network == `optimism`) {
            for (const contract of deployment.contracts) {
                if (contract.name == contractName) {
                    return contract.address;
                }
            }
        }
    }

    // If we haven't found a deployment address, throw an error
    throw new Error(`address for contract ${contractName} not found`);
};
