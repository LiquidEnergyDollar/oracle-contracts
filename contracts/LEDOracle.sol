pragma solidity >=0.8.17;

import "./interfaces/IPriceFeed.sol";
import "./interfaces/IBitcoinOracle.sol";
import "./interfaces/ILEDOracle.sol";
import "./utils/ExpMovingAvg.sol";
import "solmate/src/utils/FixedPointMathLib.sol";

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
    uint256 private immutable _koomeyTimeInMonths;
    // Using Jan 01 2016 08:00:00 GMT as start date
    uint256 private constant KOOMEY_START_DATE = 1451635200;
    uint256 private constant SECONDS_PER_THIRTY_DAYS = 2592000;

    event LEDPerETH(uint timestamp, uint256 raw, uint256 scaled, uint256 smoothed);

    constructor(
        address priceFeedOracleAddress,
        address bitcoinOracleAddress,
        uint256 seedValue,
        uint256 smoothingFactor,
        uint256 initScaleFactor,
        uint256 initKoomeyTimeInMonths
    ) {
        if (
            block.timestamp <= KOOMEY_START_DATE ||
            initKoomeyTimeInMonths <= 4 ||
            initKoomeyTimeInMonths > 100
        ) {
            revert LEDOracle__InvalidInput();
        }
        _priceFeedOracle = IPriceFeed(priceFeedOracleAddress);
        _bitcoinOracle = IBitcoinOracle(bitcoinOracleAddress);
        _expMovingAvg = new ExpMovingAvg(seedValue, smoothingFactor);
        _scaleFactor = initScaleFactor;
        _koomeyTimeInMonths = initKoomeyTimeInMonths;
    }

    /**
     * @notice Returns the LED per ETH
     * Updates the contract state to allow for moving avg
     * @return The LED/ETH ratio
     */
    function getLEDPerETH() external returns (uint256) {
        uint256 currDifficulty = _bitcoinOracle.getCurrentEpochDifficulty() * 1e18;
        // Satoshi's have 8 points of precision
        uint256 btcReward = _bitcoinOracle.getBTCIssuancePerBlock() * 1e10;
        uint256 btcPerETH = _priceFeedOracle.getBTCPerETH();

        if (btcPerETH <= 0) {
            revert LEDOracle__InvalidExchangeRate();
        }

        uint256 scaledDiff = this.scaleDifficulty(currDifficulty);

        uint256 kLED = FixedPointMathLib.divWadDown(btcReward, scaledDiff);
        uint256 scaledLED = kLED * _scaleFactor;
        uint256 smoothedLED = _expMovingAvg.pushValueAndGetAvg(scaledLED);

        emit LEDPerETH(block.timestamp, kLED, scaledLED, smoothedLED);

        return smoothedLED;
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
        uint timeDelta = block.timestamp - KOOMEY_START_DATE;
        uint256 koomeyPeriodInSecs = _koomeyTimeInMonths * SECONDS_PER_THIRTY_DAYS;
        uint256 koomeyPeriods = timeDelta / koomeyPeriodInSecs;
        uint expectedImprovement = 2 ** (1 + koomeyPeriods);
        return currDifficulty / expectedImprovement;
    }
}
