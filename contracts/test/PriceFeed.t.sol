// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.17;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "./utils/Test.sol";
import "../PriceFeed.sol";

contract PriceFeedTest is Test {
    PriceFeed public _priceFeed;
    address _btcOracle = address(0xD702DD976Fb76Fffc2D3963D037dfDae5b04E593);
    address _ethOracle = address(0x13e3Ee699D1909E989722E753853AE30b17e08c5);

    function setUp() public {
        _priceFeed = new PriceFeed(_btcOracle, _ethOracle);
    }

    function testInvalidResponse() public {
        vm.expectRevert();
        callGetBTCPerETHWithInput(0, 1);
        vm.expectRevert();
        callGetBTCPerETHWithInput(1, 0);
        vm.expectRevert();
        callGetBTCPerETHWithInput(-1, 1);
        vm.expectRevert();
        callGetBTCPerETHWithInput(1, -1);
    }

    function testGetBTCPerETHFuzzer(int256 btcPrice, int256 ethPrice) public {
        vm.assume(btcPrice > 0 && ethPrice > 0);
        // Allow room for 8 decimal places
        vm.assume(btcPrice <= 1e58 && ethPrice <= 1e58);
        callGetBTCPerETHWithInput(btcPrice, ethPrice);
    }

    function testGetBTCPerETH() public {
        // $20k
        int256 btcPrice = 2000000000000;
        // $1.5k
        int256 ethPrice = 150000000000;
        // Expect the result to be .075
        assertEq(callGetBTCPerETHWithInput(btcPrice, ethPrice), 75000000000000000);

        // $1.5k
        btcPrice = 150000000000;
        // $20k
        ethPrice = 2000000000000;
        // Expect the result to be 13.333333333333333333
        assertEq(callGetBTCPerETHWithInput(btcPrice, ethPrice), 13333333333333333333);

        // $150T
        btcPrice = 150000000000000000000;
        // $.000015
        ethPrice = 150;
        // Expect the result to be 0.000000000000000001
        assertEq(callGetBTCPerETHWithInput(btcPrice, ethPrice), 1);

        // max value
        btcPrice = 1e58;
        // max value
        ethPrice = 1e58;
        // Expect the result to be 1
        assertEq(callGetBTCPerETHWithInput(btcPrice, ethPrice), 1000000000000000000);
    }

    function callGetBTCPerETHWithInput(int256 btcPrice, int256 ethPrice) private returns (uint256) {
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

        return _priceFeed.getBTCPerETH();
    }
}
