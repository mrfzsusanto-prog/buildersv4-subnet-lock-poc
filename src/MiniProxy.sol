// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
/// Minimal ERC1967 proxy for LOCAL invariant testing only (not audited code).
contract MiniProxy {
    bytes32 internal constant _IMPL_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
    constructor(address impl, bytes memory data) {
        assembly { sstore(_IMPL_SLOT, impl) }
        if (data.length > 0) {
            (bool ok, bytes memory ret) = impl.delegatecall(data);
            require(ok, string(ret));
        }
    }
    fallback() external payable {
        assembly {
            let impl := sload(_IMPL_SLOT)
            calldatacopy(0, 0, calldatasize())
            let r := delegatecall(gas(), impl, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch r case 0 { revert(0, returndatasize()) } default { return(0, returndatasize()) }
        }
    }
    receive() external payable {}
}
