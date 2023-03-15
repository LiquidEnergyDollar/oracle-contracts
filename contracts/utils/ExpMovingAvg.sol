pragma solidity >=0.8.17;

error InvalidInput();

/**
 * @title ExpMovingAvg
 * @author LED Labs
 * @notice Tracks an exponential moving average across epochs. Averages all 
 * values within an epoch. Once the epoch boundary is crossed, the intra-epoch
 * avg is added to the global exponential avg.
 */
contract ExpMovingAvg {
    uint256 private globalValue;
    uint256 private currEpoch;
    uint256 private epochSum = 0;
    uint256 private epochCount = 0;
    uint256 private globalSmoothingFactor;
    // One day
    uint256 private constant EPOCH_PERIOD_IN_SEC = 86400;

    /**
     * @notice Creates a new EMA with the provided parameters.
     * @param seedValue The value to represent the historic moving avg
     * @param initSmoothingFactor 1/(traditional smoothing fraction)
     * Ex. if the traditional EMA smoothing factor is .05, this input should 
     * be 20.
     */
    constructor(uint256 seedValue, uint256 initSmoothingFactor) {
        globalValue = seedValue;
        if (initSmoothingFactor == 0 || initSmoothingFactor > 1000) {
            revert InvalidInput();
        }
        globalSmoothingFactor = initSmoothingFactor;
        currEpoch = getCurrEpoch();
    }

    /**
     * @notice Add a new value and get the new expontential moving avg. Rolls
     * up avgs on the epoch boundary.
     * @param value The new value to add.
     * @return The current exponential moving average considering all values
     */
    function pushValueAndGetAvg(uint256 value) external returns (uint256) {
        // Update the global value if the epoch has transitioned
        uint256 epoch = getCurrEpoch();
        if (epoch != currEpoch) {
            currEpoch = epoch;
            globalValue = getGlobalAvg();
            epochSum = 0;
            epochCount = 0;
        }

        epochSum += value;
        epochCount++;

        return getGlobalAvg();
    }

    /**
     * @return The current exponential moving average considering all values
     */
    function getGlobalAvg() public view returns (uint256) {
        uint256 epochValue = epochSum / epochCount;
        int256 delta = (int(epochValue) - int(globalValue));
        int256 weightedDelta = delta / int(globalSmoothingFactor);
        return uint256(weightedDelta + int(globalValue));
    }

    /**
     * @return The historic exponential moving average ignoring the current
     * epoch
     */
    function getHistoricAvg() external view returns (uint256) {
        return globalValue;
    }

    function getCurrEpoch() private view returns (uint256) {
        return block.timestamp / EPOCH_PERIOD_IN_SEC;
    }
}
