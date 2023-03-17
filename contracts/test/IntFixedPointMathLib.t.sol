pragma solidity >=0.8.17;

import "./utils/Test.sol";
import "./utils/Common.sol";
import "../LEDOracle.sol";
import "../utils/IntFixedPointMathLib.sol";

contract IntFixedPointMathLibTest is Test {
    function testDivWadDown() public {
        assertEq(IntFixedPointMathLib.divWadDown(1.25e18, 0.5e18), 2.5e18);
        assertEq(IntFixedPointMathLib.divWadDown(3e18, 1e18), 3e18);
        assertEq(IntFixedPointMathLib.divWadDown(2, 100000000000000e18), 0);

        assertEq(IntFixedPointMathLib.divWadDown(-1.25e18, 0.5e18), -2.5e18);
        assertEq(IntFixedPointMathLib.divWadDown(3e18, -1e18), -3e18);
        assertEq(IntFixedPointMathLib.divWadDown(2, -100000000000000e18), 0);
        assertEq(IntFixedPointMathLib.divWadDown(-3e18, -1e18), 3e18);
    }
}
