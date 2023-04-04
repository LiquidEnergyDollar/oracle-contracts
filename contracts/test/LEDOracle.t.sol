pragma solidity ^0.8.17;

import "./utils/Test.sol";
import "./utils/Common.sol";
import "../LEDOracle.sol";
import "../interfaces/IBitcoinOracle.sol";
import "../interfaces/IPriceFeed.sol";
import "abdk-libraries-solidity/ABDKMath64x64.sol";
import "forge-std/src/console2.sol";
import "solmate/src/utils/FixedPointMathLib.sol";

contract LEDOracleTest is Test {
    uint256 private constant KOOMEY_START_DATE = 1444309200; // 10/08/2015
    uint256 private constant MAX_DATE = 2104819200; // 2036
    uint256 private constant EXAMPLE_KOOMEY_PERIOD_IN_SECS = 41472000; // 16 months
    uint256 private constant EXAMPLE_DIFF_SMOOTHING_FACTOR = 30 * 8 * 24 * 1e18; // 4 month lag
    uint256 private constant EXAMPLE_PRICE_SMOOTHING_FACTOR = 30 * 18 * 24 * 1e18; // 9 month lag
    uint256 private constant ONE_HOUR_IN_SECS = 3600;
    LEDOracle public _ledOracle;
    address private _bitcoinOracle = address(0);
    address private _priceFeedOracle = address(1);

    function testConstructorSuccess() public {
        vm.warp(KOOMEY_START_DATE + 1);
        _ledOracle = new LEDOracle(
            _priceFeedOracle,
            _bitcoinOracle,
            1e18,
            EXAMPLE_DIFF_SMOOTHING_FACTOR,
            1e18,
            EXAMPLE_PRICE_SMOOTHING_FACTOR,
            1e18,
            EXAMPLE_KOOMEY_PERIOD_IN_SECS
        );
    }

    function testInvalidBlockTime() public {
        vm.warp(KOOMEY_START_DATE);
        vm.expectRevert();
        _ledOracle = new LEDOracle(
            _priceFeedOracle,
            _bitcoinOracle,
            1e18,
            EXAMPLE_DIFF_SMOOTHING_FACTOR,
            1e18,
            EXAMPLE_PRICE_SMOOTHING_FACTOR,
            1e18,
            EXAMPLE_KOOMEY_PERIOD_IN_SECS
        );
    }

    function testInvalidDifficulty() public {
        vm.warp(KOOMEY_START_DATE + 1);
        _ledOracle = new LEDOracle(
            _priceFeedOracle,
            _bitcoinOracle,
            1e18,
            EXAMPLE_DIFF_SMOOTHING_FACTOR,
            1e18,
            EXAMPLE_PRICE_SMOOTHING_FACTOR,
            1e18,
            EXAMPLE_KOOMEY_PERIOD_IN_SECS
        );
        vm.expectRevert();
        _ledOracle.scaleDifficulty(0);
    }

    function testKoomeysLawDirect() public {
        uint currDifficulty = 43551722213590e18;
        uint currTimestamp = 1679346268;
        uint avgSeed = 16982939;
        uint koomeyPeriod = 44064000;
        vm.warp(currTimestamp);

        _ledOracle = new LEDOracle(
            _priceFeedOracle,
            _bitcoinOracle,
            avgSeed,
            EXAMPLE_DIFF_SMOOTHING_FACTOR,
            1e18,
            EXAMPLE_PRICE_SMOOTHING_FACTOR,
            1e18,
            koomeyPeriod
        );

        uint256 scaledDiff = _ledOracle.scaleDifficulty(currDifficulty);
        assertEq(scaledDiff, 539862852515334113127309231517);
        // Move fwd one hour
        vm.warp(currTimestamp + ONE_HOUR_IN_SECS);
        scaledDiff = _ledOracle.scaleDifficulty(currDifficulty);
        assertEq(scaledDiff, 539832281124911441172265156151);
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
            EXAMPLE_DIFF_SMOOTHING_FACTOR,
            1e18,
            EXAMPLE_PRICE_SMOOTHING_FACTOR,
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

    function testGetUSDPerLED() public {
        uint256 currTime = 1680573848;
        vm.warp(currTime);
        uint256 usdPerBTC = 28025;
        uint256 usdPerETH = 1700;
        uint256 diffSeed = 433805858724e18;
        uint256 priceSeed = 172325e18;
        uint256 koomeyPeriod = 41472000;
        // Mock Bitcoin Oracle
        vm.mockCall(
            _bitcoinOracle,
            abi.encodeWithSelector(IBitcoinOracle.getCurrentEpochDifficulty.selector),
            abi.encode(47791177510188)
        );
        vm.mockCall(
            _bitcoinOracle,
            abi.encodeWithSelector(IBitcoinOracle.getBTCIssuancePerBlock.selector),
            abi.encode(6.25e8)
        );

        // Mock PriceFeed response
        vm.mockCall(
            _priceFeedOracle,
            abi.encodeWithSelector(IPriceFeed.getExchangeRateFeeds.selector),
            abi.encode(usdPerETH, usdPerBTC)
        );

        _ledOracle = new LEDOracle(
            _priceFeedOracle,
            _bitcoinOracle,
            diffSeed,
            EXAMPLE_DIFF_SMOOTHING_FACTOR,
            priceSeed,
            EXAMPLE_PRICE_SMOOTHING_FACTOR,
            2517591.727165182072382523e18,
            koomeyPeriod
        );
        console2.log("USD Per LED", _ledOracle.getUSDPerLED());
    }

    function testVolatilityUp() public {
        uint256 startTime = 1680572558;
        vm.warp(startTime);
        uint256 diffSeed = 47791177510188e18;
        uint256 priceSeed = 172325e18;
        uint256 usdPerBTC = 27798e18;
        // Remove Koomey's effect
        uint256 maxKoomeyPeriod = 259200000;

        // Mock Bitcoin Oracle
        vm.mockCall(
            _bitcoinOracle,
            abi.encodeWithSelector(IBitcoinOracle.getCurrentEpochDifficulty.selector),
            abi.encode(47791177510188)
        );
        vm.mockCall(
            _bitcoinOracle,
            abi.encodeWithSelector(IBitcoinOracle.getBTCIssuancePerBlock.selector),
            abi.encode(6.25e8)
        );

        // Mock PriceFeed response
        vm.mockCall(
            _priceFeedOracle,
            abi.encodeWithSelector(IPriceFeed.getExchangeRateFeeds.selector),
            abi.encode(1700e18, usdPerBTC)
        );

        _ledOracle = new LEDOracle(
            _priceFeedOracle,
            _bitcoinOracle,
            diffSeed,
            EXAMPLE_DIFF_SMOOTHING_FACTOR,
            priceSeed,
            EXAMPLE_PRICE_SMOOTHING_FACTOR,
            2517591.727165182072382523e18,
            maxKoomeyPeriod
        );
        uint hour0 = _ledOracle.getUSDPerLED();
        console2.log("USD Per LED", hour0);

        // Move to next epoch - +1 hour
        vm.warp(startTime + ONE_HOUR_IN_SECS);

        // Mock PriceFeed response
        // +1% movement
        uint256 priceUp = FixedPointMathLib.mulWadDown(usdPerBTC, 1.01e18);
        vm.mockCall(
            _priceFeedOracle,
            abi.encodeWithSelector(IPriceFeed.getExchangeRateFeeds.selector),
            abi.encode(1700e18, priceUp)
        );
        uint hour1 = _ledOracle.getUSDPerLED();
        console2.log("USD Per LED +1 percent movement", hour1);

        // Move to next epoch - +1 hour
        vm.warp(startTime + ONE_HOUR_IN_SECS + ONE_HOUR_IN_SECS);

        // Mock PriceFeed response
        // +2% movement
        priceUp = FixedPointMathLib.mulWadDown(usdPerBTC, 1.02e18);
        vm.mockCall(
            _priceFeedOracle,
            abi.encodeWithSelector(IPriceFeed.getExchangeRateFeeds.selector),
            abi.encode(1700e18, priceUp)
        );
        uint hour2 = _ledOracle.getUSDPerLED();
        console2.log("USD Per LED +2 percent movement", hour2);
        assertGt(hour1, hour0);
        assertGt(hour2, hour1);
    }

    function testVolatilityDown() public {
        uint256 startTime = 1680572558;
        vm.warp(startTime);
        uint256 diffSeed = 433805858724e18;
        uint256 priceSeed = 172325e18;
        uint256 usdPerBTC = 27798e18;
        // Remove Koomey's effect
        uint256 maxKoomeyPeriod = 259200000;
        // Mock Bitcoin Oracle
        vm.mockCall(
            _bitcoinOracle,
            abi.encodeWithSelector(IBitcoinOracle.getCurrentEpochDifficulty.selector),
            abi.encode(47791177510188)
        );
        vm.mockCall(
            _bitcoinOracle,
            abi.encodeWithSelector(IBitcoinOracle.getBTCIssuancePerBlock.selector),
            abi.encode(6.25e8)
        );

        // Mock PriceFeed response
        vm.mockCall(
            _priceFeedOracle,
            abi.encodeWithSelector(IPriceFeed.getExchangeRateFeeds.selector),
            abi.encode(1700e18, usdPerBTC)
        );

        _ledOracle = new LEDOracle(
            _priceFeedOracle,
            _bitcoinOracle,
            diffSeed,
            EXAMPLE_DIFF_SMOOTHING_FACTOR,
            priceSeed,
            EXAMPLE_PRICE_SMOOTHING_FACTOR,
            2517591.727165182072382523e18,
            maxKoomeyPeriod
        );
        uint hour0 = _ledOracle.getUSDPerLED();
        console2.log("USD Per LED", hour0);

        // Move to next epoch - +1 hour
        vm.warp(startTime + ONE_HOUR_IN_SECS);

        // Mock PriceFeed response
        // -5% movement
        uint256 priceDown = FixedPointMathLib.mulWadDown(usdPerBTC, .99e18);
        vm.mockCall(
            _priceFeedOracle,
            abi.encodeWithSelector(IPriceFeed.getExchangeRateFeeds.selector),
            abi.encode(1700e18, priceDown)
        );
        uint hour1 = _ledOracle.getUSDPerLED();
        console2.log("USD Per LED -1 percent movement", hour1);

        // Move to next epoch - +1 hour
        vm.warp(startTime + ONE_HOUR_IN_SECS + ONE_HOUR_IN_SECS);

        // Mock PriceFeed response
        // -10% movement
        priceDown = FixedPointMathLib.mulWadDown(usdPerBTC, .98e18);
        vm.mockCall(
            _priceFeedOracle,
            abi.encodeWithSelector(IPriceFeed.getExchangeRateFeeds.selector),
            abi.encode(1700e18, priceDown)
        );
        uint hour2 = _ledOracle.getUSDPerLED();
        console2.log("USD Per LED -2 percent movement", hour2);

        assertLt(hour1, hour0);
        assertLt(hour2, hour1);
    }
}
