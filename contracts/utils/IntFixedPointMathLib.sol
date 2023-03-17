// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17;

import "solmate/src/utils/FixedPointMathLib.sol";

/**
 * @title IntFixedPointMathLib
 * @author LED Labs
 * @notice Integer Fixed Point Math
 */
library IntFixedPointMathLib {
    /**
     * @notice Integer division of two numbers with 1e18 precision.
     */
    function divWadDown(int256 x, int256 y) internal pure returns (int256) {
        uint256 u_x = uint256(x);
        uint256 u_y = uint256(y);
        if (x < 0) {
            u_x = uint256(x * -1);
        }
        if (y < 0) {
            u_y = uint256(y * -1);
        }
        int256 result = int256(FixedPointMathLib.divWadDown(u_x, u_y));
        // if neg
        if (x < 0 != y < 0) {
            return result * -1;
        }
        return result;
    }
}
