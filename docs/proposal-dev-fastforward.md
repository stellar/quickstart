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

## Usage
Call the endpoint to fast-forward N ledgers from the current state:
This will fast-forward 1000 ledgers from the current state, not jump to ledger 1000.

## Implementation Notes

**Scope**
This unsafe mode is intended for local development and testing only. It should not be enabled in production or exposed to public networks.

**Endpoint Protection**
The `/advance-ledgers?count=N` endpoint is only available when the quickstart container is started with the `UNSAFE_FASTFORWARD=true` environment variable. By default this mode is disabled and the endpoint returns 404. No authentication is implemented; access control relies on keeping the container network-local.

**Limits**
There is no hard limit on `count=N` in the initial implementation. For large values, the operation may take significant time and consume resources. It is recommended to keep `N` < 100,000 per call for stability.

**Behavior**
The endpoint blocks the HTTP request until all requested ledgers are advanced. The response is returned only after completion. While advancing, Horizon, RPC, and Friendbot remain disabled to avoid inconsistencies.

**Re-enabling Services**
Horizon, RPC, and Friendbot are automatically re-enabled on the next container restart without `UNSAFE_FASTFORWARD=true`. There is no hot-reload mechanism in this proposal.
