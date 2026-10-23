// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
contract MockMOR is ERC20 {
    constructor() ERC20("MOR", "MOR") {}
    function mint(address to, uint256 amt) external { _mint(to, amt); }
}
