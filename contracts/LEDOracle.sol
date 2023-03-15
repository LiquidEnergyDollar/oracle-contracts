pragma solidity >=0.8.17;

import "./interfaces/IPriceFeed.sol";
import "./interfaces/IBitcoinOracle.sol";
import "./interfaces/ILEDOracle.sol";
import "./utils/ExpMovingAvg.sol";

error InvalidInput();
error InvalidExchangeRate();
error InvalidBTCDifficulty();

/**
 * @title LEDOracle
 * @author LED Labs
 * @notice This contract is read from any time the LED price oracle is needed
 * (e.g. minting LED, liquidations, etc). The contract’s main goal is to
 * contain the equation and state necessary for creating the LED price feed.
 */
contract LEDOracle is ILEDOracle {
    IPriceFeed private priceFeedOracle;
    IBitcoinOracle private bitcoinOracle;
    ExpMovingAvg private expMovingAvg;
    // Used for setting initial price of LED
    uint256 private scaleFactor;
    // Using Jan 01 2016 08:00:00 GMT as start date
    uint256 private constant KOOMEY_START_DATE = 1451635200;
    uint256 private constant SECONDS_PER_MONTH = 2592000;
    uint256 private koomeyTimeInMonths;

    event LEDPerETH(uint timestamp, uint256 raw, uint256 scaled, uint256 smoothed);

    constructor(
        address priceFeedOracleAddress,
        address bitcoinOracleAddress,
        uint256 seedValue,
        uint256 smoothingFactor,
        uint256 initScaleFactor,
        uint256 initKoomeyTimeInMonths
    ) {
        if(block.timestamp <= KOOMEY_START_DATE || initKoomeyTimeInMonths > 100) {
            revert InvalidInput();
        }
        priceFeedOracle = IPriceFeed(priceFeedOracleAddress);
        bitcoinOracle = IBitcoinOracle(bitcoinOracleAddress);
        expMovingAvg = new ExpMovingAvg(seedValue, smoothingFactor);
        scaleFactor = initScaleFactor;
        koomeyTimeInMonths = initKoomeyTimeInMonths;
    }

    /**
     * @notice Returns the LED per ETH
     * Updates the contract state to allow for moving avg
     * @return The LED/ETH ratio
     */
    function getLEDPerETH() external returns (uint256) {
        uint256 currDifficulty = bitcoinOracle.getCurrentEpochDifficulty();
        uint256 btcReward = bitcoinOracle.getBTCIssuancePerBlock();
        uint256 btcPerETH = priceFeedOracle.getBTCPerETH();

        if(btcPerETH <= 0) {
            revert InvalidExchangeRate();
        }

        uint256 scaledDiff = this.scaleDifficulty(currDifficulty);

        uint256 kLED = btcReward / scaledDiff;
        uint256 scaledLED = kLED / scaleFactor;
        uint256 smoothedLED = expMovingAvg.pushValueAndGetAvg(scaledLED);

        emit LEDPerETH(block.timestamp, kLED, scaledLED, smoothedLED);

        return smoothedLED;
    }

    /**
     * @notice Scale difficulty to account for energy efficiency improvements
     * Energy efficiency doubles in KOOMEY_DOUBLE_TIME_IN_MONTHS
     * @return The scaled difficulty based on Koomey's law
     */
    function scaleDifficulty(uint256 currDifficulty) external view returns (uint256) {
        if(currDifficulty <= 0) {
            revert InvalidBTCDifficulty();
        }
        uint timeDelta = block.timestamp - KOOMEY_START_DATE;
        uint expectedImprovement = 2 ** (1 + timeDelta / (koomeyTimeInMonths * SECONDS_PER_MONTH));
        return currDifficulty / expectedImprovement;
    }
}
