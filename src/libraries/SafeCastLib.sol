library SafeCastLib {
    function safeCastTo224(uint256 x) internal pure returns (uint224 y) {
        require(x <= type(uint224).max);

        y = uint224(x);
    }
}
