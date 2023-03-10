pragma solidity >=0.8.17;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "./interfaces/IPriceFeed.sol";

contract PriceFeed is IPriceFeed {
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

    // Queries chainlink price feeds for ETH/USD + BTC/USD
    // Calculates BTC/ETH
    function getBTCPerETH() external view returns (int) {
        (
            uint80 btcUSDRoundID,
            int btcUSDPrice,
            uint btcUSDStartedAt,
            uint btcUSDTimeStamp,
            uint80 btcUSDAnsweredInRound
        ) = btcUSD.latestRoundData();
        (
            uint80 ethUSDRoundID,
            int ethUSDPrice,
            uint ethUSDStartedAt,
            uint ethUSDTimeStamp,
            uint80 ethUSDAnsweredInRound
        ) = ethUSD.latestRoundData();

        // TODO: Check recency

        require(btcUSDPrice > 0 && ethUSDPrice > 0, "Unexpected response from chainlink");

        return (ethUSDPrice / btcUSDPrice);
    }
}
