pragma solidity >=0.8.17;

contract ExpMovingAvg {
    uint256 private globalValue;
    uint256 private currEpoch;
    uint256 private epochSum = 0;
    uint256 private epochCount = 0;
    uint256 private globalSmoothingFactor;
    // One day
    uint256 private constant EPOCH_PERIOD_IN_SEC = 86400;

    constructor(uint256 seedValue, uint256 initSmoothingFactor) {
        globalValue = seedValue;
        globalSmoothingFactor = initSmoothingFactor;
        currEpoch = getCurrEpoch();
    }

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

    function getCurrEpoch() private view returns (uint256) {
        return block.timestamp / EPOCH_PERIOD_IN_SEC;
    }

    function getGlobalAvg() private view returns (uint256) {
        uint256 epochValue = epochSum / epochCount;
        return (epochValue - globalValue) * globalSmoothingFactor + globalValue;
    }
}
