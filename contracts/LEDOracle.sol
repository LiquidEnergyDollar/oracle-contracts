pragma solidity >=0.8.17;

import "./interfaces/IPriceFeed.sol";
import "./interfaces/IBitcoinOracle.sol";
import "./interfaces/ILEDOracle.sol";
import "./utils/ExpMovingAvg.sol";
import "solmate/src/utils/FixedPointMathLib.sol";
import "abdk-libraries-solidity/ABDKMath64x64.sol";
import "forge-std/src/console2.sol";

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
    ExpMovingAvg private immutable _expMovingAvg;
    // Used for setting initial price of LED
    uint256 private immutable _scaleFactor;
    uint256 private immutable _koomeyTimeInSeconds;
    // Using Jan 01 2016 08:00:00 GMT as start date
    uint256 private constant KOOMEY_START_DATE = 1451635200;

    event LEDPerETH(uint timestamp, uint256 raw, uint256 scaled, uint256 smoothed, uint256 inETH);

    constructor(
        address priceFeedOracleAddress,
        address bitcoinOracleAddress,
        uint256 seedValue,
        uint256 smoothingFactor,
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
        _expMovingAvg = new ExpMovingAvg(seedValue, smoothingFactor);
        _scaleFactor = initScaleFactor;
        _koomeyTimeInSeconds = initKoomeyTimeInSeconds;
    }

    /**
     * @notice Returns the LED per ETH
     * Updates the contract state to allow for moving avg
     * @return The LED/ETH ratio
     */
    function getLEDPerETH() external returns (uint256) {
        uint256 currDifficulty = _bitcoinOracle.getCurrentEpochDifficulty() * 1e18;
        console2.log("currDifficulty", currDifficulty);
        // Satoshi's have 8 points of precision
        uint256 btcReward = _bitcoinOracle.getBTCIssuancePerBlock() * 1e10;
        console2.log("btcReward", btcReward);
        uint256 btcPerETH = _priceFeedOracle.getBTCPerETH();

        if (btcPerETH <= 0) {
            revert LEDOracle__InvalidExchangeRate();
        }

        uint256 scaledDiff = this.scaleDifficulty(currDifficulty);
        console2.log("scaledDiff", scaledDiff);

        uint256 kLED = FixedPointMathLib.divWadDown(btcReward, scaledDiff);
        console2.log("kLED", kLED);
        uint256 smoothedLED = _expMovingAvg.pushValueAndGetAvg(kLED);
        console2.log("smoothedLED", smoothedLED);
        uint256 scaledLED = FixedPointMathLib.mulWadDown(smoothedLED, _scaleFactor);

        uint256 inETH = FixedPointMathLib.divWadDown(scaledLED, btcPerETH);

        emit LEDPerETH(block.timestamp, kLED, scaledLED, smoothedLED, inETH);

        return inETH;
    }

    /**
     * @notice Scale difficulty to account for energy efficiency improvements
     * Energy efficiency doubles in KOOMEY_DOUBLE_TIME_IN_MONTHS
     * @return The scaled difficulty based on Koomey's law
     */
    function scaleDifficulty(uint256 currDifficulty) external view returns (uint256) {
        if (currDifficulty < 1e18) {
            revert LEDOracle__InvalidBTCDifficulty();
        }
        console2.log("block.timestamp", block.timestamp);
        uint timeDelta = block.timestamp - KOOMEY_START_DATE;
        console2.log("timeDelta", timeDelta);
        // We need to convert everything to 64.64 notation so that we can do 
        // 2^x where x is not a whole number
        int128 koomeyPeriods = ABDKMath64x64.divu(timeDelta, _koomeyTimeInSeconds);
        console2.log("koomeyPeriods", koomeyPeriods);
        int128 koomeyPeriodsPlusOne = ABDKMath64x64.add(ABDKMath64x64.fromUInt(1), koomeyPeriods);
        int128 expectedImprovement64 = ABDKMath64x64.exp_2(koomeyPeriodsPlusOne);
        console2.log("expectedImprovement", expectedImprovement64);
        int128 expectedImprovementInv = ABDKMath64x64.inv(expectedImprovement64);
        console2.log("expectedImprovementInv", expectedImprovementInv);
        return ABDKMath64x64.mulu(expectedImprovementInv, currDifficulty);
    }
}
