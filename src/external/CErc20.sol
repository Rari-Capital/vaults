// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.6;

interface CErc20 {
    function isCEther() external view returns (bool);

    function balanceOf(address owner) external view returns (uint256);

    function balanceOfUnderlying(address owner) external returns (uint256);

    function redeem(uint256 redeemTokens) external returns (uint256);

    function redeemUnderlying(uint256 redeemAmount) external returns (uint256);

    function mint(uint256 mintAmount) external returns (uint256);

    function mint() external payable returns (uint256);

    // TODO: Maybe add underlying so we can check when entering a pool that the cToken accepts the right asset?
    // function underlying() external view returns (address);

    // function admin() external view returns (address);

    // function adminHasRights() external view returns (bool);

    // function fuseAdminHasRights() external view returns (bool);

    // function symbol() external view returns (string memory);

    // function decimals() external view returns (uint256);

    // function comptroller() external view returns (address);

    // function adminFeeMantissa() external view returns (uint256);

    // function fuseFeeMantissa() external view returns (uint256);

    // function reserveFactorMantissa() external view returns (uint256);

    // function totalReserves() external view returns (uint256);

    // function totalAdminFees() external view returns (uint256);

    // function totalFuseFees() external view returns (uint256);

    // function borrowRatePerBlock() external view returns (uint256);

    // function supplyRatePerBlock() external view returns (uint256);

    // function totalBorrowsCurrent() external returns (uint256);

    // function borrowBalanceStored(address account) external view returns (uint256);

    // function exchangeRateStored() external view returns (uint256);

    // function getCash() external view returns (uint256);
}
