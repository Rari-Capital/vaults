// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.6;

interface Strategy {
    function balanceOfUnderlying(address owner) external returns (uint256);

    function redeemUnderlying(uint256 redeemAmount) external returns (uint256);

    function mint(uint256 mintAmount) external returns (uint256);

    // TODO: Maybe add underlying so we can check when entering a cToken that it accepts the right asset?
    // function underlying() external view returns (address);

    // TODO: Ether support
    // function mint() external payable returns (uint256);
    // function isCEther() external view returns (bool);
}
