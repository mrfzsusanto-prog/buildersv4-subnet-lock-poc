// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// Minimal cheatcode interface (avoids forge-std dependency).
interface Vm {
    function warp(uint256) external;
    function roll(uint256) external;
    function prank(address) external;
    function startPrank(address) external;
    function stopPrank() external;
    function deal(address, uint256) external;
    function deal(address, address, uint256) external;
    function deal(address, address, uint256, bool) external;
    function expectRevert() external;
    function expectRevert(bytes4) external;
    function label(address, string calldata) external;
    function load(address, bytes32) external view returns (bytes32);
    function store(address, bytes32, bytes32) external;
}

abstract contract TestLite {
    Vm internal constant vm = Vm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function fail(string memory msg_) internal pure {
        revert(string(abi.encodePacked("FAIL: ", msg_)));
    }
    function assertTrue(bool c, string memory m) internal pure {
        if (!c) fail(m);
    }
    function assertEq(uint256 a, uint256 b, string memory m) internal pure {
        if (a != b)
            fail(string(abi.encodePacked(m, " left=", _u(a), " right=", _u(b))));
    }
    function assertEq(address a, address b, string memory m) internal pure {
        if (a != b) fail(m);
    }
    function assertGe(uint256 a, uint256 b, string memory m) internal pure {
        if (a < b) fail(m);
    }
    function assertLe(uint256 a, uint256 b, string memory m) internal pure {
        if (a > b)
            fail(string(abi.encodePacked(m, " left=", _u(a), " right=", _u(b))));
    }
    function assertGt(uint256 a, uint256 b, string memory m) internal pure {
        if (a <= b) fail(m);
    }
    function _u(uint256 v) internal pure returns (string memory) {
        if (v == 0) return "0";
        uint256 t = v;
        uint256 d;
        while (t > 0) { d++; t /= 10; }
        bytes memory b = new bytes(d);
        while (v > 0) { b[--d] = bytes1(uint8(48 + (v % 10))); v /= 10; }
        return string(b);
    }
    function bound(uint256 x, uint256 lo, uint256 hi) internal pure returns (uint256) {
        if (hi <= lo) return lo;
        return lo + (x % (hi - lo + 1));
    }
}
