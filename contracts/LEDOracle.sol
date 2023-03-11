pragma solidity >=0.8.17;

import "./interfaces/IPriceFeed.sol";
import "./interfaces/IBitcoinOracle.sol";
import "./interfaces/ILEDOracle.sol";

/**
 * This contract is read from any time the LED price oracle is needed (e.g. 
 * minting LED, liquidations, etc). The contract’s main goal is to contain the
 * equation and state necessary for creating the LED price feed.
 */
contract LEDOracle is ILEDOracle {
    IPriceFeed private priceFeedOracle;
    IBitcoinOracle private bitcoinOracle;
    // Used for setting initial price of LED
    uint256 private scaleFactor;
    // Using Jan 01 2016 08:00:00 GMT as start date
    uint private constant KOOMEY_START_DATE = 1451635200;
    uint private constant KOOMEY_DOUBLE_TIME = 47304000;

    constructor (
        address priceFeedOracleAddress, 
        address bitcoinOracleAddress, 
        uint256 initScaleFactor
    ) {
        require (block.timestamp > KOOMEY_START_DATE, "Invalid KOOMEY_START_DATE");
        priceFeedOracle = IPriceFeed(priceFeedOracleAddress);
        bitcoinOracle = IBitcoinOracle(bitcoinOracleAddress);
        scaleFactor = initScaleFactor;
    }

	// @notice Returns the LED per ETH
    // Updates the contract state to allow for moving avg
    function getLEDPerETH() external returns (uint256) {

        uint256 currDifficulty = bitcoinOracle.getCurrentEpochDifficulty();
        uint256 btcReward = bitcoinOracle.getBTCIssuancePerBlock();
        int256 btcPerETH = priceFeedOracle.getBTCPerETH();

        require(btcPerETH > 0, "Unexpected exchange rate");

        uint256 scaledDiff = this.scaleDifficulty(currDifficulty);

        uint256 kLED = btcReward / scaledDiff;

        return kLED / scaleFactor;
    }

    /**
     * Scale difficulty to account for energy efficiency improvements
     * Energy efficiency doubles in KOOMEY_DOUBLE_TIME
     */
    function scaleDifficulty(uint256 currDifficulty) external view returns (uint256) {
        require(currDifficulty > 0, "Unexpected bitcoin difficulty");
        uint timeDelta = block.timestamp - KOOMEY_START_DATE;
        uint expectedImprovement = 2**(1 + timeDelta/KOOMEY_DOUBLE_TIME);
        return currDifficulty / expectedImprovement;
    }
}