pragma solidity ^0.8.17;

interface ILEDOracle {
    // @notice Returns the LED per ETH
    // Updates the contract state to allow for moving avg
    function getLEDPerETH() external returns (uint256);
}
