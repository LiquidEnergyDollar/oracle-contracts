// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17;

/**
 * @title common
 * @author LED Labs
 * @notice General utility functions for tests
 */
library common {

    /**
     * @notice Converts the seed value to be within the range
     * Useful for fuzz tests since applying assume() to small ranges throws an
     * exception after too many failed attempts.
     */
    function convertToRange(uint value, uint start, uint end) internal pure returns (uint) {
        uint range = end - start;
        uint offset = value % range + 1;
        return start + offset; 
    }
}