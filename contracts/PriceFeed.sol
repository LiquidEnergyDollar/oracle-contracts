pragma solidity >=0.8.17;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "./interfaces/IPriceFeed.sol";
import "solmate/src/utils/FixedPointMathLib.sol";

/**
 * @title Price Feed
 * @author LED Labs
 * @notice Provides a price oracle for the system
 * @dev Watch out for the oracle manipulations attacks
 */
contract PriceFeed is IPriceFeed {
    error PriceFeed__InvalidPrice();

    AggregatorV3Interface internal _btcUSD;
    AggregatorV3Interface internal _ethUSD;

    /**
     * Network: Optimism
     * Aggregator: BTC/USD
     * Address: 0xD702DD976Fb76Fffc2D3963D037dfDae5b04E593
     * Aggregator: ETH/USD
     * Address: 0x13e3Ee699D1909E989722E753853AE30b17e08c5
     */
    constructor(address btcOracle, address ethOracle) {
        _btcUSD = AggregatorV3Interface(btcOracle);
        _ethUSD = AggregatorV3Interface(ethOracle);
    }

    /**
     * @notice Queries Chainlink price feeds for ETH/USD + BTC/USD
     * Calculates BTC/ETH with 18 decimals of precision
     */
    function getBTCPerETH() external view returns (uint256) {
        (, int256 btcUSDPrice, , , ) = _btcUSD.latestRoundData();
        (, int256 ethUSDPrice, , , ) = _ethUSD.latestRoundData();

        // TODO: Check recency

        // prices have to be > 0
        if (btcUSDPrice <= 0 || ethUSDPrice <= 0) {
            revert PriceFeed__InvalidPrice();
        }

        // Chainlink prices are in 1e8 precision
        // Convert them to 1e18 before division
        uint256 ethUSD = uint256(ethUSDPrice * 1e10);
        uint256 btcUSD = uint256(btcUSDPrice * 1e10);
        return FixedPointMathLib.divWadDown(ethUSD, btcUSD);
    }
}
