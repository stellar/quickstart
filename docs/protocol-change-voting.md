# Witnessing protocol changes voted on by name

This walks through an experimental stellar-core build in which validators vote
on protocol changes **by name** rather than by protocol version number.

## What changed

Today a validator votes for a specific protocol version:

```
upgrades?mode=set&upgradetime=...&protocolversion=29
```

The number both identifies the change and determines the resulting version, so
two candidate changes cannot be proposed at once — they would both claim 29.

In this build a validator votes for a named change instead:

```
upgrades?mode=set&upgradetime=...&protocolchange=disable-bump-sequence
```

When the quorum accepts a named change, `ledgerVersion` increments by one and
the name is recorded in the ledger header. The number no longer identifies the
change -- the header does -- so two changes can be proposed at the same time,
and whichever the quorum accepts first takes the next protocol version.

A named change still has to land on a version the build supports, so this image
builds core with `--enable-next-protocol-version-unsafe-for-production` (raising
the supported maximum to 29) while the local network still starts at 28. That
leaves exactly one version of headroom for the change to consume.

The `protocol-change-vote` image in [`images.json`](../images.json) builds core
from [`leighmcculloch/stellar-core`][core-branch] on the `vote-upgrades-by-name`
branch.

[core-branch]: https://github.com/leighmcculloch/stellar-core/tree/vote-upgrades-by-name

## Run a local network

The core admin HTTP interface on port 11626 is where votes are cast, so expose
it as well as the usual port 8000:

```console
docker run --rm -it \
  -p 8000:8000 -p 11626:11626 \
  stellar/quickstart:protocol-change-vote --local
```

Wait until the log reports the network is up and the protocol upgrade to 28 has
completed.

## 1. See which changes this build knows about

A node only votes for, and only accepts, changes it knows how to apply, so the
set of names is a property of the build:

```console
$ curl -s http://localhost:11626/upgrades?mode=listchanges | jq
[
  {
    "name": "disable-bump-sequence",
    "description": "Stop supporting the BumpSequence operation."
  }
]
```

Note the starting protocol version:

```console
$ curl -s http://localhost:11626/info | jq -r '.info.ledger.version'
28
```

## 2. Confirm BumpSequence works

Submit a `BumpSequence` operation — via the Lab at http://localhost:8000/lab, or
any SDK pointed at http://localhost:8000. It should succeed.

## 3. Vote for the named change

With a single validator the local network is its own quorum, so the vote is
accepted on the next ledger:

```console
curl -s "http://localhost:11626/upgrades?mode=set&upgradetime=1970-01-01T00:00:00Z&protocolchange=disable-bump-sequence"
```

An unknown name is rejected up front rather than being voted on:

```console
$ curl -s "http://localhost:11626/upgrades?mode=set&upgradetime=1970-01-01T00:00:00Z&protocolchange=nope"
unknown protocolchange: 'nope' (see upgrades?mode=listchanges)
```

## 4. Watch the protocol version increment

Within a few seconds the change is accepted and the version goes up by one —
note that nothing in the vote named "29":

```console
$ curl -s http://localhost:11626/info | jq -r '.info.ledger.version'
29
```

Core logs the activation:

```
Activated protocol change 'disable-bump-sequence'; protocol version 28 -> 29
```

## 5. Confirm BumpSequence is now rejected

Submit the same `BumpSequence` operation again. It now fails with
`opNOT_SUPPORTED`, because the operation is gated on the named change rather
than on a version number:

```cpp
return protocolVersionStartsFrom(header.ledgerVersion, ProtocolVersion::V_10) &&
       !isProtocolChangeActive(header, PROTOCOL_CHANGE_DISABLE_BUMP_SEQUENCE);
```

## Why the ordering matters

Because the accepted change — not the proposer — decides the number, two
changes proposed at the same time resolve in whatever order the quorum accepts
them. If `disable-bump-sequence` is accepted first it takes version 29 and a
second change takes 30; if the other is accepted first the assignment is
reversed. The ledger header records the activated names, so every node agrees
on which behaviour each version carries regardless of the order.

This is covered by the `"the change accepted first determines the next protocol
version"` test in core's `UpgradesTests.cpp`, which runs the same two changes in
both orders.

## Caveats

This is an experiment, not a proposed protocol change:

- The XDR change (a `LEDGER_UPGRADE_PROTOCOL_CHANGE` union arm and a
  `LedgerHeaderExtensionV2` recording activated names) is vendored into the core
  fork rather than landed in [`stellar/stellar-xdr`][xdr], so the fork no longer
  uses the XDR submodule. It sits behind the `PROTOCOL_CHANGE_BY_NAME` XDR
  feature flag, so the .x files still hash identically to upstream and core's
  C++/Rust XDR identity check is unmodified.
- Horizon does not recognise protocol version 29, so the image sets
  `horizon_skip_protocol_version_check`.
- The other components in the image (Horizon, RPC, Lab) are built against the
  upstream XDR, which has no `LEDGER_UPGRADE_PROTOCOL_CHANGE` arm, so they
  cannot decode the upgrade step itself. Read the vote and its effect from
  core's own HTTP interface, as above, rather than from ledger meta.
- The legacy `protocolversion=N` vote still exists, since the network has to be
  able to reach its current version before any named change is proposed. The two
  cannot be voted for together, because both move `ledgerVersion`.
- There is only one version of headroom in this image, so only one named change
  can be activated. Activating a second would need the supported maximum raised
  again. Core's own test suite exercises the two-changes-in-either-order case.

[xdr]: https://github.com/stellar/stellar-xdr
