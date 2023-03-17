pragma solidity >=0.8.17;

interface IBitcoinOracle {
    /// @notice Returns the difficulty of the current epoch.
    function getCurrentEpochDifficulty() external view returns (uint256);

    /// @notice Returns the difficulty of the previous epoch.
    function getPrevEpochDifficulty() external view returns (uint256);

    /// @notice Returns the current BTC block reward.
    function getBTCIssuancePerBlock() external view returns (uint256);
}
