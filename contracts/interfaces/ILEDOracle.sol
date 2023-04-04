pragma solidity ^0.8.17;

interface ILEDOracle {
    // @notice Returns the USD per LED
    // Updates the contract state to allow for moving avg
    function getUSDPerLED() external returns (uint256);
}
