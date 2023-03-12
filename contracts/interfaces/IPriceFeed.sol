pragma solidity >=0.8.17;

interface IPriceFeed {
    function getBTCPerETH() external view returns (int);
}