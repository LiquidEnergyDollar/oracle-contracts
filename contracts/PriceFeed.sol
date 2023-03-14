pragma solidity >=0.8.17;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "./interfaces/IPriceFeed.sol";

/**
 * @title Price Feed
 * @author LED Labs
 * @notice Provides a price oracle for the system
 * @dev Watch out for the oracle manipulations attacks
 */
contract PriceFeed is IPriceFeed {
    error InvalidPrice();

    AggregatorV3Interface internal btcUSD;
    AggregatorV3Interface internal ethUSD;

    /**
     * Network: Optimism
     * Aggregator: BTC/USD
     * Address: 0xD702DD976Fb76Fffc2D3963D037dfDae5b04E593
     * Aggregator: ETH/USD
     * Address: 0x13e3Ee699D1909E989722E753853AE30b17e08c5
     */
    constructor(address btcOracle, address ethOracle) {
        btcUSD = AggregatorV3Interface(btcOracle);
        ethUSD = AggregatorV3Interface(ethOracle);
    }

    /**
     * @notice Queries Chainlink price feeds for ETH/USD + BTC/USD
     * Calculates BTC/ETH with 18 decimals of precision
     */
    function getBTCPerETH() external view returns (uint256) {
        (
            uint80 btcUSDRoundID,
            int256 btcUSDPrice,
            uint256 btcUSDStartedAt,
            uint256 btcUSDTimeStamp,
            uint80 btcUSDAnsweredInRound
        ) = btcUSD.latestRoundData();
        (
            uint80 ethUSDRoundID,
            int256 ethUSDPrice,
            uint256 ethUSDStartedAt,
            uint256 ethUSDTimeStamp,
            uint80 ethUSDAnsweredInRound
        ) = ethUSD.latestRoundData();

        // TODO: Check recency

        // prices have to be > 0 or < 1e58
        if (btcUSDPrice <= 0 || ethUSDPrice <= 0 || btcUSDPrice > 1e58 || ethUSDPrice > 1e58) {
            revert InvalidPrice();
        }

        return (uint256)((ethUSDPrice * 10 ** 18) / btcUSDPrice);
    }
}
