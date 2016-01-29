# docker-stellar-core-horizon

Docker container which starts a single-node [Stellar](https://www.stellar.org) network with following services:

* [stellar-core](https://github.com/stellar/stellar-core)
* [horizon-importer](https://github.com/stellar/horizon-importer)
* [horizon](https://github.com/stellar/horizon)

To start using test lumens use this key pair:
```
GBRPYHIL2CI3FNQ4BXLFMNDLFJUNPU2HY3ZMFSHONUCEOASW7QC7OX2H
SDHOAMBNLGCE2MV5ZKIVZAQD3VCLGP53P3OBSBI6UN5L5XZI5TKHFQL4
```

It does not have a persistent storage (yet?).

### Motivation

This container can be used for integration tests or for testing stellar-core + horizon stack locally (no internet connection needed).

## Usage

```
docker run -p 8000 -d --name=stellar-core-horizon stellar/stellar-core-horizon:latest
```

You can then run `docker ps` to find a port on which horizon is listening.

## Logs

```
docker logs -f stellar-core-horizon
```

## Local build

```
docker build -t stellar/stellar-core-horizon .
```
