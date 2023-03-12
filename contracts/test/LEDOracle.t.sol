pragma solidity >=0.8.17;

import "./utils/Test.sol";
import "../LEDOracle.sol";

contract LEDOracleTest is Test {
    uint private constant KOOMEY_START_DATE = 1451635200;
    uint private constant KOOMEY_DOUBLE_TIME = 47304000;
    LEDOracle public ledOracle;
    address private bitcoinOracle = address(0);
    address private priceFeedOracle = address(1);

    function testConstructorSuccess() public {
        vm.warp(KOOMEY_START_DATE + 1);
        ledOracle = new LEDOracle(bitcoinOracle, priceFeedOracle, 1);
    }
    function testInvalidBlockTime() public {
        vm.warp(KOOMEY_START_DATE);        
        vm.expectRevert();
        ledOracle = new LEDOracle(bitcoinOracle, priceFeedOracle, 1);
    }
    function testInvalidDifficulty() public {
        vm.warp(KOOMEY_START_DATE + 1);   
        ledOracle = new LEDOracle(bitcoinOracle, priceFeedOracle, 1);     
        vm.expectRevert();
        ledOracle.scaleDifficulty(0);
    }

    function testKoomeysLaw(uint256 currDifficulty, uint currTimestamp) public {
        // timestamp is between 2016 and 2116
        vm.assume(currTimestamp > KOOMEY_START_DATE);
        vm.assume(currTimestamp < 4607308800);
        vm.warp(currTimestamp);

        ledOracle = new LEDOracle(bitcoinOracle, priceFeedOracle, 1);
        
        if (currDifficulty == 0) {
            vm.expectRevert();
            ledOracle.scaleDifficulty(currDifficulty);
        } else {
            uint timeDelta = currTimestamp - KOOMEY_START_DATE;
            uint expectedImprovement = 2**(1 + timeDelta/KOOMEY_DOUBLE_TIME);

            uint256 scaledDiff = ledOracle.scaleDifficulty(currDifficulty);
            
            assertEq(scaledDiff, currDifficulty / expectedImprovement);
        }
    }
}