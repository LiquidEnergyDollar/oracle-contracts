// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "./utils/Test.sol";
import "../PriceFeed.sol";

contract PriceFeedTest is Test {
    PriceFeed public _priceFeed;
    address _btcOracle = address(0xD702DD976Fb76Fffc2D3963D037dfDae5b04E593);
    address _ethOracle = address(0x13e3Ee699D1909E989722E753853AE30b17e08c5);
    int256 constant MAX_PRICE = 1e49;

    function setUp() public {
        _priceFeed = new PriceFeed(_btcOracle, _ethOracle);
    }

    function testInvalidResponse() public {
        vm.expectRevert();
        mockOracleResponses(0, 1);
        vm.expectRevert();
        mockOracleResponses(1, 0);
        vm.expectRevert();
        mockOracleResponses(-1, 1);
        vm.expectRevert();
        mockOracleResponses(1, -1);
    }

    function testGetExchangeRateFeedsFuzzer(int256 btcPrice, int256 ethPrice) public {
        vm.assume(btcPrice > .1e18 && ethPrice > .1e18);
        // Allow room for 8 decimal places
        vm.assume(btcPrice <= MAX_PRICE && ethPrice <= MAX_PRICE);
        callGetExchangeRateFeedsWithInput(btcPrice, ethPrice);
    }

    function testGetExchangeRateFeeds() public {
        // $20k
        int256 btcPrice = 20000e8;
        // $1.5k
        int256 ethPrice = 1500e8;
        callGetExchangeRateFeedsWithInput(btcPrice, ethPrice);

        // $1.5k
        btcPrice = 1500e8;
        // $20k
        ethPrice = 20000e8;
        callGetExchangeRateFeedsWithInput(btcPrice, ethPrice);

        // $150T
        btcPrice = 1500000000000e8;
        // $.000015
        ethPrice = 150;
        callGetExchangeRateFeedsWithInput(btcPrice, ethPrice);

        // max value
        btcPrice = MAX_PRICE;
        // max value
        ethPrice = MAX_PRICE;
        callGetExchangeRateFeedsWithInput(btcPrice, ethPrice);
    }

    function callGetExchangeRateFeedsWithInput(int256 btcPrice, int256 ethPrice) private {
        (uint256 btcPerETH, uint256 usdPerBTC) = mockOracleResponses(btcPrice, ethPrice);
        assertEq(btcPerETH, uint256(ethPrice * 1e10));
        assertEq(usdPerBTC, uint256(btcPrice * 1e10));
    }
    function mockOracleResponses(int256 btcPrice, int256 ethPrice) private
    returns (uint256, uint256) {
        // BTC chainlink contract
        vm.mockCall(
            _btcOracle,
            abi.encodeWithSelector(AggregatorV3Interface.latestRoundData.selector),
            abi.encode(1, btcPrice, 1, 1, 1)
        );

        // ETH chainlink contract
        vm.mockCall(
            _ethOracle,
            abi.encodeWithSelector(AggregatorV3Interface.latestRoundData.selector),
            abi.encode(1, ethPrice, 1, 1, 1)
        );

        return _priceFeed.getExchangeRateFeeds();
    }
}
