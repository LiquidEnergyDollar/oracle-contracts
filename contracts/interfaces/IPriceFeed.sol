pragma solidity ^0.8.17;

interface IPriceFeed {
    /**
     * @return USD/ETH and USD/BTC ratios with 18 points of precision
     */
    function getExchangeRateFeeds() external view returns (uint256, uint256);
}
