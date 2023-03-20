pragma solidity ^0.8.17;

import "./utils/Test.sol";
import "./utils/Common.sol";
import "../LEDOracle.sol";
import "../utils/ExpMovingAvg.sol";
import "../utils/IntFixedPointMathLib.sol";
import "forge-std/src/console2.sol";

contract TestAccessControl {
    function tryToPushValueAndGetAvg(ExpMovingAvg expMovingAvg) public {
        expMovingAvg.pushValueAndGetAvg(1e18);
    }
}

contract EMATest is Test {
    ExpMovingAvg private _expMovingAvg;
    uint256[] private _values;
    // One day
    uint256 private constant EPOCH_PERIOD_IN_SEC = 3600;
    uint256 private constant KOOMEY_START_DATE = 1451635200;
    uint256 private constant EXAMPLE_SMOOTHING_FACTOR = 20e18;

    function testConstructorSuccess() public {
        _expMovingAvg = new ExpMovingAvg(1e18, EXAMPLE_SMOOTHING_FACTOR);
    }

    function testConstructorFailures() public {
        vm.expectRevert();
        _expMovingAvg = new ExpMovingAvg(1e18, 0);
    }

    function testAccessControl() public {
        // Owner should be this EMATest contract
        _expMovingAvg = new ExpMovingAvg(1e18, EXAMPLE_SMOOTHING_FACTOR);
        TestAccessControl ac = new TestAccessControl();
        // Calling pushValueAndGetAvg from another contract should fail
        vm.expectRevert();
        ac.tryToPushValueAndGetAvg(_expMovingAvg);
    }

    function testSimpleAvg() public {
        _expMovingAvg = new ExpMovingAvg(2870150562289237, EXAMPLE_SMOOTHING_FACTOR);
        uint currAvg = _expMovingAvg.pushValueAndGetAvg(2870150562289237);
        assertEq(currAvg, 2870150562289237);

        _expMovingAvg = new ExpMovingAvg(1e18, EXAMPLE_SMOOTHING_FACTOR);
        currAvg = _expMovingAvg.pushValueAndGetAvg(2870150562289237);
        assertEq(currAvg, 950143507528114462);

        _expMovingAvg = new ExpMovingAvg(1e18, EXAMPLE_SMOOTHING_FACTOR);
        currAvg = _expMovingAvg.pushValueAndGetAvg(2e18);
        assertEq(currAvg, 1.05e18);
    }

    function testIntraEpochAvg(uint256 seedValue, uint256 addValue) public {
        // Allow room for 18 decimal places
        vm.assume(addValue < 1e59 && seedValue < 1e59);
        _expMovingAvg = new ExpMovingAvg(seedValue, EXAMPLE_SMOOTHING_FACTOR);
        _values = [1e18, 2e18, 3e18, addValue];
        testEMA(seedValue, EXAMPLE_SMOOTHING_FACTOR, _values);
    }

    function testIntraEpochAvgRandomSmoothing(
        uint256 seedValue,
        uint256 addValue,
        uint256 smoothingFactorSeed
    ) public {
        // Allow room for 18 decimal places
        vm.assume(addValue < 1e59 && seedValue < 1e59);

        // smoothingFactor > 0 and <= 1000
        uint smoothingFactor = Common.convertToRange(smoothingFactorSeed, 0, 1000e18);

        _expMovingAvg = new ExpMovingAvg(seedValue, smoothingFactor);
        _values = [1e18, 2e18, 3e18, addValue];
        testEMA(seedValue, smoothingFactor, _values);
    }

    function testDescendingIntraEpochAvg(uint256 seedValue, uint256 addValue) public {
        // Allow room for 18 decimal places
        vm.assume(addValue < 1e59 && seedValue < 1e59);
        _expMovingAvg = new ExpMovingAvg(seedValue, EXAMPLE_SMOOTHING_FACTOR);
        _values = [1e20, 1e18, 1e16, addValue];
        testEMA(seedValue, EXAMPLE_SMOOTHING_FACTOR, _values);
    }

    function testCrossEpochAvg() public {
        vm.warp(KOOMEY_START_DATE);

        _expMovingAvg = new ExpMovingAvg(1e18, EXAMPLE_SMOOTHING_FACTOR);
        uint currAvg = _expMovingAvg.pushValueAndGetAvg(4e18);
        assertEq(currAvg, 1.15e18);

        // next epoch
        vm.warp(KOOMEY_START_DATE + EPOCH_PERIOD_IN_SEC);
        currAvg = _expMovingAvg.pushValueAndGetAvg(2e18);
        assertEq(currAvg, 1.1925e18);
    }

    function testMissedEpochAvg(uint256 addValue) public {
        vm.warp(KOOMEY_START_DATE);
        testIntraEpochAvg(1e18, 4e18);
        // avg should be 1075e15
        uint seedValue = 1075e15;

        // skipping forward 5 epochs
        vm.warp(KOOMEY_START_DATE + (EPOCH_PERIOD_IN_SEC * 5));

        // Allow room for 18 decimal places
        vm.assume(addValue < 1e59);
        testIntraEpochAvg(seedValue, 4e18);
    }

    function testCrossEpochAvgVariableStart(uint256 addValue) public {
        // Allow room for 18 decimal places
        vm.assume(addValue < 1e59);
        vm.warp(KOOMEY_START_DATE);
        testIntraEpochAvg(addValue, 4e18);
        uint seedValue = _expMovingAvg.getHistoricAvg();

        // next epoch
        vm.warp(KOOMEY_START_DATE + EPOCH_PERIOD_IN_SEC);

        testIntraEpochAvg(seedValue, 4e18);
    }

    function testEMA(uint256 seedValue, uint smoothingFactor, uint[] memory _valuesToAdd) private {
        _expMovingAvg = new ExpMovingAvg(seedValue, smoothingFactor);
        for (uint i = 0; i < _valuesToAdd.length; i++) {
            uint currAvg = _expMovingAvg.pushValueAndGetAvg(_valuesToAdd[i]);

            int delta = int(_valuesToAdd[i]) - int(seedValue);
            int weightedDelta = IntFixedPointMathLib.divWadDown(delta, int(smoothingFactor));
            uint expected = uint(weightedDelta + int(seedValue));
            assertEq(currAvg, expected);
        }
    }
}
