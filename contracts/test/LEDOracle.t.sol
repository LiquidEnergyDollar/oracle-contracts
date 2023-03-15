pragma solidity >=0.8.17;

import "./utils/Test.sol";
import "./utils/Common.sol";
import "../LEDOracle.sol";

contract LEDOracleTest is Test {
    uint256 private constant KOOMEY_START_DATE = 1451635200; // 2016
    uint256 private constant MAX_DATE = 4607308800; // 2116
    uint256 private constant SECONDS_PER_MONTH = 2592000;
    LEDOracle public ledOracle;
    address private bitcoinOracle = address(0);
    address private priceFeedOracle = address(1);

    function testConstructorSuccess() public {
        vm.warp(KOOMEY_START_DATE + 1);
        ledOracle = new LEDOracle(bitcoinOracle, priceFeedOracle, 1e18, 20, 1, 15);
    }

    function testInvalidBlockTime() public {
        vm.warp(KOOMEY_START_DATE);
        vm.expectRevert();
        ledOracle = new LEDOracle(bitcoinOracle, priceFeedOracle, 1e18, 20, 1, 15);
    }

    function testInvalidDifficulty() public {
        vm.warp(KOOMEY_START_DATE + 1);
        ledOracle = new LEDOracle(bitcoinOracle, priceFeedOracle, 1e18, 20, 1, 15);
        vm.expectRevert();
        ledOracle.scaleDifficulty(0);
    }

    function testKoomeysLaw(
        uint currDifficulty,
        uint currTimestampSeed,
        uint koomeyMonthsSeed
    ) public {
        // timestamp > 2016 and <= 2116
        uint currTimestamp = common.convertToRange(currTimestampSeed, KOOMEY_START_DATE, MAX_DATE);
        // Koomey months > 4 and <= 100
        uint koomeyMonths = common.convertToRange(koomeyMonthsSeed, 4, 100);
        vm.warp(currTimestamp);

        ledOracle = new LEDOracle(bitcoinOracle, priceFeedOracle, 1e18, 20, 1, koomeyMonths);

        if (currDifficulty == 0) {
            vm.expectRevert();
            ledOracle.scaleDifficulty(currDifficulty);
        } else {
            uint timeDelta = currTimestamp - KOOMEY_START_DATE;
            uint koomeyPeriod = (koomeyMonths * SECONDS_PER_MONTH);
            uint expectedImprovement = 2 ** (1 + timeDelta / koomeyPeriod);

            uint256 scaledDiff = ledOracle.scaleDifficulty(currDifficulty);

            assertEq(scaledDiff, currDifficulty / expectedImprovement);
        }
    }
}
