// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "./utils/Test.sol";
import "../PriceFeed.sol";

contract PriceFeedTest is Test {
    PriceFeed public priceFeed;
    address btcOracle = address(0xD702DD976Fb76Fffc2D3963D037dfDae5b04E593);
    address ethOracle = address(0x13e3Ee699D1909E989722E753853AE30b17e08c5);

    function setUp() public {
        priceFeed = new PriceFeed(btcOracle, ethOracle);
    }

    function testGetBTCPerETH(int btcPrice, int ethPrice) public {
        // BTC chainlink contract
        vm.mockCall(
            btcOracle,
            abi.encodeWithSelector(AggregatorV3Interface.latestRoundData.selector),
            abi.encode(1, btcPrice, 1, 1, 1)
        );

        // ETH chainlink contract
        vm.mockCall(
            ethOracle,
            abi.encodeWithSelector(AggregatorV3Interface.latestRoundData.selector),
            abi.encode(1, ethPrice, 1, 1, 1)
        );
        if (ethPrice <= 0 || btcPrice <= 0) {
            vm.expectRevert();
            priceFeed.getBTCPerETH();
        } else {
            assertEq(priceFeed.getBTCPerETH(), (ethPrice / btcPrice));
        }
    }
}
