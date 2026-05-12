## Summary
Proposal for a `dev-fastforward` preset implementing the endpoint requested by @teddav in #932: 
"An endpoint to automatically advance by N ledgers" for local Soroban testing.

## Problem
As described in #932:
1. Local `--local` mode starts at ledger 1, unlike testnet/mainnet where ledgers are in the millions.
2. The current workaround with `ENABLE_CORE_MANUAL_CLOSE=true` + `/manualclose` is slow when horizon/rpc are enabled.
3. Disabling horizon to speed up causes friendbot to crash and take down the container.
4. Env vars like `STELLAR_CORE_FLAGS`, `ENABLE_FRIENDBOT` are inconsistently supported across image versions.

## Proposed Solution
Add `--preset dev-fastforward` that:
- Enables `--core-config-unsafe-mode` to disable archive publishing/validation
- Disables horizon/rpc/friendbot by default during fast-forward
- Exposes `/advance-ledgers?count=N` endpoint as requested by @teddav

This allows reaching ledger 1M+ in minutes, matching real network conditions for time-based contract testing.

## Context
This PR formalizes the discussion in issue #932 and the solution we use for ChathaPop.app testing, 
which cuts local test time ~90%.

Reference: #932
