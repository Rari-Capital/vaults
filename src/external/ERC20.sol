// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "../interfaces/IERC20.sol";

contract ERC20 is IERC20 {
    uint256 internal _totalSupply;

    mapping(address => uint256) internal _balanceOf;
    mapping(address => mapping(address => uint256)) internal _allowance;

    string public symbol;
    uint256 public immutable decimals;
    string public name;

    constructor(
        string memory name_,
        string memory symbol_,
        uint256 decimals_
    ) {
        name = name_;
        symbol = symbol_;
        decimals = decimals_;
    }

    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address guy) public view virtual override returns (uint256) {
        return _balanceOf[guy];
    }

    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowance[owner][spender];
    }

    function approve(address spender, uint256 wad) public virtual override returns (bool) {
        return _approve(msg.sender, spender, wad);
    }

    function transfer(address dst, uint256 wad) public virtual override returns (bool) {
        return _transfer(msg.sender, dst, wad);
    }

    function transferFrom(
        address src,
        address dst,
        uint256 wad
    ) public virtual override returns (bool) {
        uint256 allowed = _allowance[src][msg.sender];
        if (src != msg.sender && allowed != type(uint256).max) {
            require(allowed >= wad, "ERC20: Insufficient approval");
            _approve(src, msg.sender, allowed - wad);
        }

        return _transfer(src, dst, wad);
    }

    function _transfer(
        address src,
        address dst,
        uint256 wad
    ) internal virtual returns (bool) {
        require(_balanceOf[src] >= wad, "ERC20: Insufficient balance");
        _balanceOf[src] = _balanceOf[src] - wad;
        _balanceOf[dst] = _balanceOf[dst] + wad;

        emit Transfer(src, dst, wad);

        return true;
    }

    function _approve(
        address owner,
        address spender,
        uint256 wad
    ) internal virtual returns (bool) {
        _allowance[owner][spender] = wad;
        emit Approval(owner, spender, wad);
        return true;
    }

    function _mint(address dst, uint256 wad) internal virtual {
        _balanceOf[dst] = _balanceOf[dst] + wad;
        _totalSupply = _totalSupply + wad;
        emit Transfer(address(0), dst, wad);
    }

    function _burn(address src, uint256 wad) internal virtual {
        require(_balanceOf[src] >= wad, "ERC20: Insufficient balance");
        _balanceOf[src] = _balanceOf[src] - wad;
        _totalSupply = _totalSupply - wad;
        emit Transfer(src, address(0), wad);
    }
}
