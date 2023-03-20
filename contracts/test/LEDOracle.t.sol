pragma solidity ^0.8.17;

import "./utils/Test.sol";
import "./utils/Common.sol";
import "../LEDOracle.sol";
import "../interfaces/IBitcoinOracle.sol";
import "../interfaces/IPriceFeed.sol";
import "abdk-libraries-solidity/ABDKMath64x64.sol";
import "forge-std/src/console2.sol";

contract LEDOracleTest is Test {
    uint256 private constant KOOMEY_START_DATE = 1444334400; // 10/10/2015
    uint256 private constant MAX_DATE = 2104819200; // 2036
    uint256 private constant EXAMPLE_KOOMEY_PERIOD = 38880000;
    uint256 private constant EXAMPLE_SMOOTHING_FACTOR = 20e18;
    LEDOracle public _ledOracle;
    address private _bitcoinOracle = address(0);
    address private _priceFeedOracle = address(1);

    function testConstructorSuccess() public {
        vm.warp(KOOMEY_START_DATE + 1);
        _ledOracle = new LEDOracle(
            _priceFeedOracle,
            _bitcoinOracle,
            1e18,
            EXAMPLE_SMOOTHING_FACTOR,
            1e18,
            EXAMPLE_KOOMEY_PERIOD
        );
    }

    function testInvalidBlockTime() public {
        vm.warp(KOOMEY_START_DATE);
        vm.expectRevert();
        _ledOracle = new LEDOracle(
            _priceFeedOracle,
            _bitcoinOracle,
            1e18,
            EXAMPLE_SMOOTHING_FACTOR,
            1e18,
            EXAMPLE_KOOMEY_PERIOD
        );
    }

    function testInvalidDifficulty() public {
        vm.warp(KOOMEY_START_DATE + 1);
        _ledOracle = new LEDOracle(
            _priceFeedOracle,
            _bitcoinOracle,
            1e18,
            EXAMPLE_SMOOTHING_FACTOR,
            1e18,
            EXAMPLE_KOOMEY_PERIOD
        );
        vm.expectRevert();
        _ledOracle.scaleDifficulty(0);
    }

    function testKoomeysLaw(
        uint currDifficulty,
        uint currTimestampSeed,
        uint koomeyPeriodSeed
    ) public {
        vm.assume(currDifficulty > 1e18 && currDifficulty < 1e50);
        // timestamp > 2016 and <= 2037
        uint currTimestamp = Common.convertToRange(currTimestampSeed, KOOMEY_START_DATE, MAX_DATE);
        // Koomey months > 4 months and <= 100 months
        uint koomeyPeriod = Common.convertToRange(koomeyPeriodSeed, 12375190, 259200000);
        vm.warp(currTimestamp);

        _ledOracle = new LEDOracle(
            _priceFeedOracle,
            _bitcoinOracle,
            1e18,
            EXAMPLE_SMOOTHING_FACTOR,
            1e18,
            koomeyPeriod
        );

        uint timeDelta = currTimestamp - KOOMEY_START_DATE;
        int128 koomeyPeriods = ABDKMath64x64.divu(timeDelta, koomeyPeriod);
        int128 koomeyPeriodsPlusOne = ABDKMath64x64.add(ABDKMath64x64.fromUInt(1), koomeyPeriods);
        int128 expectedImprovement64 = ABDKMath64x64.exp_2(koomeyPeriodsPlusOne);
        int128 expectedImprovementInv = ABDKMath64x64.inv(expectedImprovement64);
        uint expectedScaledDiff = ABDKMath64x64.mulu(expectedImprovementInv, currDifficulty);

        uint256 scaledDiff = _ledOracle.scaleDifficulty(currDifficulty);

        assertEq(scaledDiff, expectedScaledDiff);
    }

    function testGetLEDPerETH() public {
        uint256 currTime = 1679346268;
        vm.warp(currTime);
        uint256 btcPerEth = 0.062608081877e18;
        uint256 avgSeed = 16982939;
        uint256 smoothingFactor = 8000e18;
        uint256 koomeyPeriod = 40176000;
        // Mock Bitcoin Oracle
        vm.mockCall(
            _bitcoinOracle,
            abi.encodeWithSelector(IBitcoinOracle.getCurrentEpochDifficulty.selector),
            abi.encode(43551722213590)
        );
        vm.mockCall(
            _bitcoinOracle,
            abi.encodeWithSelector(IBitcoinOracle.getBTCIssuancePerBlock.selector),
            abi.encode(6.25e8)
        );

        // Mock PriceFeed response
        vm.mockCall(
            _priceFeedOracle,
            abi.encodeWithSelector(IPriceFeed.getBTCPerETH.selector),
            abi.encode(btcPerEth)
        );

        _ledOracle = new LEDOracle(
            _priceFeedOracle,
            _bitcoinOracle,
            avgSeed,
            smoothingFactor,
            6539921657784e18,
            koomeyPeriod
        );
        console2.log("LED Per ETH", _ledOracle.getLEDPerETH());
    }
}
