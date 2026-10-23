# PoC — BuildersV4 subnet-admin lock rug (permanent freeze of staker principal)

Self-contained Foundry project (dependencies vendored under `src/`, no setup step).

Run (one command, Base mainnet fork pinned at block 52992637; any archive-capable Base RPC works):

```
forge test --match-contract ForkLockRugTest --fork-url <BASE_RPC_URL> --fork-block-number 52992637
```

Expected: `[PASS] test_lockRug_fork()` — a fresh victim stakes 1,000 MOR into a fresh
attacker-created subnet, withdraws normally after the advertised 7-day lock (control),
then the subnet admin raises the lock to `type(uint128).max` with one `editSubnet` call
and the victim's remaining 999 MOR become permanently unwithdrawable (asserted on-chain).
