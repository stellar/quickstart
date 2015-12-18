# docker-stellar-core-horizon

Docker container which includes:

* [stellar-core](https://github.com/stellar/stellar-core)
* [horizon-importer](https://github.com/stellar/horizon-importer)
* [horizon](https://github.com/stellar/horizon)

After starting the container the single-node Stellar network will be created with horizon-importer and horizon services. To start using test lumens use this key pair:
```
GBRPYHIL2CI3FNQ4BXLFMNDLFJUNPU2HY3ZMFSHONUCEOASW7QC7OX2H
SDHOAMBNLGCE2MV5ZKIVZAQD3VCLGP53P3OBSBI6UN5L5XZI5TKHFQL4
```

## Usage

```
docker run -p 8000 -d stellar/stellar-core-horizon:latest
```

You can then run `docker ps` to find a port on which horizon is listening.

## Logs

```
docker logs -f [process name]
```
