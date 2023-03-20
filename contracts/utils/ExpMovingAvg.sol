pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "solmate/src/utils/FixedPointMathLib.sol";
import "../utils/IntFixedPointMathLib.sol";

/**
 * @title ExpMovingAvg
 * @author LED Labs
 * @notice Tracks an exponential moving average across epochs. Averages all
 * values within an epoch. Once the epoch boundary is crossed, the intra-epoch
 * avg is added to the global exponential avg.
 */
contract ExpMovingAvg is Ownable {
    error ExpMovingAvg__InvalidInput();

    uint256 private _globalValue;
    uint256 private _currEpoch;
    uint256 private _epochValue = 0;
    uint256 private _globalSmoothingFactor;
    // One hour
    uint256 private constant EPOCH_PERIOD_IN_SEC = 3600;

    /**
     * @notice Creates a new EMA with the provided parameters.
     * @param seedValue The value to represent the historic moving avg
     * @param initSmoothingFactor 1/(traditional smoothing fraction)
     * Ex. if the traditional EMA smoothing factor is .05, this input should
     * be 20e18.
     */
    constructor(uint256 seedValue, uint256 initSmoothingFactor) {
        _globalValue = seedValue;
        if (initSmoothingFactor == 0 || initSmoothingFactor > 1000e18) {
            revert ExpMovingAvg__InvalidInput();
        }
        _globalSmoothingFactor = initSmoothingFactor;
        _currEpoch = getCurrEpoch();
    }

    /**
     * @notice Add a new value and get the new expontential moving avg. Rolls
     * up avgs on the epoch boundary.
     * @param value The new value to add.
     * @return The current exponential moving average considering all values
     */
    function pushValueAndGetAvg(uint256 value) external onlyOwner returns (uint256) {
        // Update the global value if the epoch has transitioned
        uint256 epoch = getCurrEpoch();
        if (epoch != _currEpoch) {
            _currEpoch = epoch;
            _globalValue = getGlobalAvg();
        }

        _epochValue = value;

        return getGlobalAvg();
    }

    /**
     * @return The current exponential moving average considering all values
     */
    function getGlobalAvg() public view returns (uint256) {
        int256 delta = (int(_epochValue) - int(_globalValue));
        int256 weightedDelta = IntFixedPointMathLib.divWadDown(delta, int(_globalSmoothingFactor));
        return uint256(weightedDelta + int(_globalValue));
    }

    /**
     * @return The historic exponential moving average ignoring the current
     * epoch
     */
    function getHistoricAvg() external view returns (uint256) {
        return _globalValue;
    }

    function getCurrEpoch() private view returns (uint256) {
        uint256 timestamp = block.timestamp;
        return timestamp / EPOCH_PERIOD_IN_SEC;
    }
}
