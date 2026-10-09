# config-settings
This directory contains the current Soroban settings upgrade files for `--limits testnet`, `--limits unlimited`, and `--limits mainnet`. Keep these top-level presets in sync with the current networks as they evolve. The testnet and unlimited presets preserve their existing resource limits and use the current CPU and memory cost tables from the checked-in mainnet snapshot.

Protocols 26 and later use the top-level presets. The `p21` through `p25` directories retain presets for older protocol overrides, since the supported cost types depend on the protocol.

`mainnet.json` contains the current mainnet Soroban settings and is selected with `--limits mainnet` option.
