pragma solidity ^0.8.17;

import "./interfaces/IPriceFeed.sol";
import "./interfaces/IBitcoinOracle.sol";
import "./interfaces/ILEDOracle.sol";
import "./utils/ExpMovingAvg.sol";
import "solmate/src/utils/FixedPointMathLib.sol";
import "abdk-libraries-solidity/ABDKMath64x64.sol";

/**
 * @title LEDOracle
 * @author LED Labs
 * @notice This contract is read from any time the LED price oracle is needed
 * (e.g. minting LED, liquidations, etc). The contract’s main goal is to
 * contain the equation and state necessary for creating the LED price feed.
 */
contract LEDOracle is ILEDOracle {
    error LEDOracle__InvalidInput();
    error LEDOracle__InvalidExchangeRate();
    error LEDOracle__InvalidBTCDifficulty();

    IPriceFeed private immutable _priceFeedOracle;
    IBitcoinOracle private immutable _bitcoinOracle;
    ExpMovingAvg private immutable _diffExpMovingAvg;
    ExpMovingAvg private immutable _rewardExpMovingAvg;
    // Used for setting initial price of LED
    uint256 private immutable _scaleFactor;
    uint256 private immutable _koomeyTimeInSeconds;
    // Using Oct 08 2015 13:00:00 GMT as start date
    uint256 private constant KOOMEY_START_DATE = 1444309200;
    // Last updated price
    uint256 public lastLedPricePerETH;

    event LEDOracleUpdated(
        uint256 timestamp,
        uint256 currDifficulty,
        uint256 btcReward,
        uint256 usdPerBTC,
        uint256 kDiff,
        uint256 smoothedKDiff,
        uint256 smoothedBlockRewardUSD,
        uint256 smoothedLEDInUSD,
        uint256 scaledLEDInUSD
    );

    constructor(
        address priceFeedOracleAddress,
        address bitcoinOracleAddress,
        uint256 diffEMASeedValue,
        uint256 diffSmoothingFactor,
        uint256 priceEMASeedValue,
        uint256 priceSmoothingFactor,
        uint256 initScaleFactor,
        uint256 initKoomeyTimeInSeconds
    ) {
        if (
            block.timestamp <= KOOMEY_START_DATE ||
            initKoomeyTimeInSeconds <= 10368000 || // ~4 months
            initKoomeyTimeInSeconds > 259200000 // ~100 months
        ) {
            revert LEDOracle__InvalidInput();
        }
        _priceFeedOracle = IPriceFeed(priceFeedOracleAddress);
        _bitcoinOracle = IBitcoinOracle(bitcoinOracleAddress);
        _diffExpMovingAvg = new ExpMovingAvg(diffEMASeedValue, diffSmoothingFactor);
        _rewardExpMovingAvg = new ExpMovingAvg(priceEMASeedValue, priceSmoothingFactor);
        _scaleFactor = initScaleFactor;
        _koomeyTimeInSeconds = initKoomeyTimeInSeconds;
    }

    /**
     * @notice Returns the USD/LED
     * Updates the contract state to allow for moving avg
     * @return The USD/LED ratio
     */
    function getUSDPerLED() external returns (uint256) {
        uint256 currDifficulty = _bitcoinOracle.getCurrentEpochDifficulty() * 1e18;
        // Satoshi's have 8 points of precision
        uint256 btcReward = _bitcoinOracle.getBTCIssuancePerBlock() * 1e10;
        (, uint256 usdPerBTC) = _priceFeedOracle.getExchangeRateFeeds();

        if (usdPerBTC == 0) {
            revert LEDOracle__InvalidExchangeRate();
        }

        // First scale difficulty with Koomey's law
        uint256 kDiff = scaleDifficulty(currDifficulty);
        // Smooth this difficulty using the EMA
        uint256 smoothedKDiff = _diffExpMovingAvg.pushValueAndGetAvg(kDiff);
        // Calculate the block reward in USD
        uint256 blockRewardInUSD = FixedPointMathLib.mulWadDown(btcReward, usdPerBTC);
        // Smooth this block reward using the EMA
        uint256 smoothedBlockRewardUSD = _rewardExpMovingAvg.pushValueAndGetAvg(blockRewardInUSD);
        // EMA(reward) / EMA(kDiff)
        uint256 smoothedLEDInUSD = FixedPointMathLib.divWadDown(
            smoothedBlockRewardUSD,
            smoothedKDiff
        );
        // Scale to hit the $1 target as a starting value
        uint256 scaledLEDInUSD = FixedPointMathLib.mulWadDown(smoothedLEDInUSD, _scaleFactor);

        emit LEDOracleUpdated(
            block.timestamp,
            currDifficulty,
            btcReward,
            usdPerBTC,
            kDiff,
            smoothedKDiff,
            smoothedBlockRewardUSD,
            smoothedLEDInUSD,
            scaledLEDInUSD
        );

        return scaledLEDInUSD;
    }

    /**
     * @notice Scale difficulty to account for energy efficiency improvements
     * Energy efficiency doubles in _koomeyTimeInSeconds
     * @return The scaled difficulty based on Koomey's law
     */
    function scaleDifficulty(uint256 currDifficulty) public view returns (uint256) {
        if (currDifficulty < 1e18) {
            revert LEDOracle__InvalidBTCDifficulty();
        }
        uint256 timeDelta = block.timestamp - KOOMEY_START_DATE;
        // We need to convert everything to 64.64 notation so that we can do
        // 2^x where x is not a whole number
        int128 koomeyPeriods = ABDKMath64x64.divu(timeDelta, _koomeyTimeInSeconds);
        int128 koomeyPeriodsPlusOne = ABDKMath64x64.add(ABDKMath64x64.fromUInt(1), koomeyPeriods);
        int128 expectedImprovement64 = ABDKMath64x64.exp_2(koomeyPeriodsPlusOne);
        int128 expectedImprovementInv = ABDKMath64x64.inv(expectedImprovement64);
        return ABDKMath64x64.mulu(expectedImprovementInv, currDifficulty);
    }
}
