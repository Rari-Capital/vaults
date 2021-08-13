// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.6;

import {ERC20} from "solmate/erc20/ERC20.sol";

contract MockCERC20 is ERC20("Mock CETH", "MCETH", 18) {
    function mint() external payable returns (uint256) {
        _mint(msg.sender, msg.value);

        // TODO: We should prolly return actual error codes and not revert as per CERC20 spec
        return 0;
    }

    function redeem(uint256 redeemTokens) external returns (uint256) {
        payable(msg.sender).transfer(redeemTokens);
        _burn(msg.sender, redeemTokens);

        // TODO: We should prolly return actual error codes and not revert as per CERC20 spec
        return 0;
    }

    function redeemUnderlying(uint256 redeemTokens) external returns (uint256) {
        payable(msg.sender).transfer(redeemTokens);
        _burn(msg.sender, redeemTokens);

        // TODO: We should prolly return actual error codes and not revert as per CERC20 spec
        return 0;
    }

    function balanceOfUnderlying(address) external view returns (uint256) {
        return address(this).balance;
    }

    function isCEther() external pure returns (bool) {
        return true;
    }
}

contract MockWETH is ERC20("Mock WETH", "mWETH", 18) {
    function deposit() public payable {
        balanceOf[msg.sender] += msg.value;
    }

    function withdraw(uint256 wad) public {
        require(balanceOf[msg.sender] >= wad);
        balanceOf[msg.sender] -= wad;
        payable(msg.sender).transfer(wad);
    }
}
