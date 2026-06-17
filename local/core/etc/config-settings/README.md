# config-settings
This directory contains Soroban settings upgrade files for each default protocol version (set with the arg `PROTOCOL_VERSION_DEFAULT`) specified on each on the three builds (`latest`, `testing`, and `future`). They need to be separated by protocol version because the number of cost types is dependant on protocol, and we specifically want to capture the cpu cost type changes we make outside of protocol boundaries.  

The latest protocol version's `testnet.json` is kept in sync with live testnet by the `Update Config Settings` workflow, which opens a PR when the committed values drift.
