pragma solidity 0.8.6;

interface Weth {
    function deposit() external payable;

    function withdraw(uint256) external;
}
