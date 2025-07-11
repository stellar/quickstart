# Stellar Quickstart Docker Image

[![Apache 2.0 licensed](https://img.shields.io/badge/license-apache%202.0-blue.svg)](LICENSE)
[![Ask DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/stellar/quickstart)


Stellar Quickstart is the fastest way to spin up a complete Stellar blockchain development environment. The quickstart image is explicitly intended for development and testing environments, not production deployments. For production deployment guidance, see the individual service documentation for [stellar-core](https://developers.stellar.org/docs/validators](https://developers.stellar.org/docs/validators/admin-guide/prerequisites)), [stellar-rpc](https://developers.stellar.org/docs/data/apis/horizon/admin-guide/overview), and [Horizon](https://developers.stellar.org/docs/data/apis/horizon/admin-guide/overview).


### Tip
> [!TIP]  
> Install the [`stellar-cli`] and start development containers running this image with:
>
> ```
> stellar container start
> ```

[`stellar-cli`]: https://github.com/stellar/stellar-cli


## Details

This docker image provides a simple way to run all the components of a Stellar network locally or in CI for development and testing.

> [!IMPORTANT]  
> This docker image is intended for use in development, not production. See these docs for how to run Stellar services in production:
> - [How to run Stellar Core in production](https://developers.stellar.org/docs/run-core-node/)
> - [How to run Horizon in production](https://developers.stellar.org/docs/data/horizon/admin-guide/overview)
> - [How to run RPC in production](https://developers.stellar.org/docs/data/rpc/admin-guide)

This image provides a default, non-validating, ephemeral configuration that should work for most developers. By configuring a container using this image with a host-based volume (described below in the "Usage" section) an operator gains access to full configuration customization and persistence of data.

The image uses the following software:

- [PostgreSQL](https://www.postgresql.org) 12 is used for storing both stellar-core and horizon data.
- [stellar-core](https://github.com/stellar/stellar-core)
- [horizon](https://github.com/stellar/go/tree/master/services/horizon)
- [friendbot](https://github.com/stellar/go/tree/master/services/friendbot)
- [lab](https://github.com/stellar/laboratory)
- [stellar-rpc](https://github.com/stellar/stellar-rpc/tree/main/cmd/stellar-rpc)
- [Supervisord](http://supervisord.org) is used from managing the processes of the above services.

## Usage

To use this project successfully, you should first decide a few things:

First, decide whether you want your container to be part of the public, production Stellar network (referred to as the _pubnet_) or the test network (called testnet) that we recommend you use while developing software because you need not worry about losing money on the testnet. Alternatively, choose to run a local network (called local) which allows you to run your own acellerated private Stellar network for testing.

Next, you must decide whether you will use a docker volume or not. When not using a volume, we say that the container is in _ephemeral mode_, that is, nothing will be persisted between runs of the container. _Persistent mode_ is the alternative, which should be used in the case that you need to either customize your configuration (such as to add a validation seed) or would like avoid a slow catchup to the Stellar network in the case of a crash or server restart. We recommend persistent mode for anything besides a development or test environment.

Finally, you must decide what ports to expose. The software in these images listen on 4 ports, each of which you may or may not want to expose to the network your host system is connected to. A container that exposes no ports isn't very useful, so we recommend at a minimum you expose the horizon http port. See the "Ports" section below for a more nuanced discussion regarding the decision about what ports to expose.

After deciding on the questions above, you can setup your container. Please refer to the appropriate section below based upon what mode you will run the container in.

### Network Options

Provide either `--pubnet`, `--testnet` or `--local` as a command line flag when starting the container to determine which network (and base configuration file) to use.

#### `--pubnet`

In public network mode, the node will join the public, production Stellar network.

_Note: In pubnet mode the node will consume more disk, memory, and CPU resources because of the size of the ledger and frequency of transactions. If disk space warnings occur and the image is being used on a Docker runtime that uses a VM, like that of macOS and Windows, the VM may need to have its disk space allocation increased._

#### `--testnet`

In test network mode, the node will join the network that developers use while developing software. Use the [Stellar Lab](https://laboratory.stellar.org/#account-creator?network=test) to create an account on the test network.

#### `--futurenet`

In futurenet network mode, the node will join the [Soroban] test network that developers use while developing smart contracts on Stellar.

[Soroban]: https://soroban.stellar.org

#### `--local`

In local network mode, you can optionally pass:

- `--protocol-version {version}` to run a specific protocol version (defaults to latest version).

- `--limits {limits}` to configure specific Soroban resource limits to one of:
  - `default` leaves limits set extremely low which is stellar-core's default configuration
  - `testnet` sets limits to match those used on testnet (the default quickstart configuration)
  - `unlimited` sets limits to the maximum resources that can be configured

**Note: The `--enable` options behaves differently in local network mode, see [Service Options](#service-otions) for more details.**
The network passphrase of the network defaults to:

```
Standalone Network ; February 2017
```

Set the network passphrase in the SDK or tool you're using. If an incorrect network passphrase is used in clients signing transactions, the transactions will fail with a bad authentication error.

The root account of the network is fixed to:

```
Public Key: GBZXN7PIRZGNMHGA7MUUUF4GWPY5AYPV6LY4UV2GL6VJGIQRXFDNMADI
Secret Key: SC5O7VZUXDJ6JBDSZ74DSERXL7W3Y5LTOAMRF7RQRL3TAGAPS7LUVG3L
```

The root account is derived from the network passphrase and if the network passphrase is changed the root account will change. To find out the root account when changing the network passphrase view the logs for stellar-core on its first start. See [Viewing logs](#viewing-logs) for more details.

In local network mode a ledger occurs every one second and so transactions
are finalized faster than on deployed networks.

_Note_: The local network in this container is not suitable for any production use as it has a fixed root account. Any private network intended for production use would also required a unique network passphrase.

### Service Options

The image runs all services available by default, but can be configured to run only certain services as needed. The option for configuring which services run is the `--enable` option.

The option takes a comma-separated list of service names to enable. To enable all services which is the default behavior, use:

```
--enable core,horizon,rpc,lab
```

To run only select services, simply specify only those services. For example, to enable the RPC, use:

```
--enable rpc
```

To enable [Stellar Lab](https://github.com/stellar/laboratory) which will use the local network:

```
--enable lab
```

**Note: In `--local` mode the `core` service always runs no matter what options are passed, the `friendbot` faucet service runs whenever `horizon` is running, and `horizon` is run when `rpc` is requested so that friendbot is available.**

### Stellar Lab

Stellar Lab is an interactive toolkit for exploring and testing on the Stellar network. It allows developers to build, sign, simulate, and submit transactions, and to make requests to both the RPC and Horizon APIs. You can also run Lab locally as part of Quickstart, backed by your own RPC, Horizon, and local network setup.

When running Lab in Quickstart, Lab is available at:

```
http://localhost:8000/lab
```

### Faucet (Friendbot)

Stellar development/test networks use friendbot as a faucet for the native asset.

When running in local, testnet, and futurenet modes friendbot is available on `:8000/friendbot` and can be used to fund a new account.

For example:

```
$ curl http://localhost:8000/friendbot?addr=G...
```

_Note: In local mode a local friendbot is running. In testnet and futurenet modes requests to the local `:8000/friendbot` endpoint will be proxied to the friendbot deployments for the respective network._


### Soroban Development

The RPC Server will be avaialble on port 8000 of the container, and the base URL path for Stellar RPC will be `http://<container_host>:8000/rpc`. This endpoint uses [JSON-RPC](https://www.jsonrpc.org/specification) protocol. Refer to example usages in [soroban-example-dapp](https://github.com/stellar/soroban-example-dapp).

To enable stellar rpc admin endpoint for access to metrics and [Go pprof (profiling)](https://pkg.go.dev/net/http/pprof), include the `--enable-stellar-rpc-admin-endpoint` flag, the HTTP endpoint will be listening on container port 6061, which can be exposed with standard docker port rule `-p "6061:6061"`, the published endpoints are:

```
http://<container_host>:6061/metrics
http://<container_host>:6061/debug/pprof/
```

### Soroban Diagnostic Events

Soroban diagnostic events contain logs about internal events that have occurred while a contract is executing. They're particularly useful for debugging why a contract trapped (panicked).

To enable Soroban diagnostic events provide the following command line flag when starting the container:
`--enable-soroban-diagnostic-events`

In local network mode diagnostics are enabled by default and can be disabled with:
`--disable-soroban-diagnostic-events`

_Note: Diagnostic events are unmetered and their execution is not metered or contrained by network limits or transaction resource limits. This means the resources consumed by an instance with diagnostic events enabled may exceed resources typically required by a deployment with diagnostic events disabled._

### Deploy to Digital Ocean

You can deploy the quickstart image to DigitalOcean by clicking the button below. It will by default create a container that can be used for development and testing, running the `latest` tag, in ephemeral mode, and on the `local` network.

[![Deploy to DO](https://www.deploytodo.com/do-btn-blue.svg)](https://cloud.digitalocean.com/apps/new?repo=https://github.com/stellar/quickstart/tree/master)

After clicking the button above, the deployment can be configured to deploy a different variant of the image, or join a different network such as `testnet` or `futurenet` by changing environment variables.

Some example configurations that can be used are:

- Local network matching pubnet:
  `IMAGE`: `stellar/quickstart:latest`
  `NETWORK`: `local`
- Local network matching testnet:
  `IMAGE`: `stellar/quickstart:testing`
  `NETWORK`: `local`
- Testnet node:
  `IMAGE`: `stellar/quickstart:testnet`
  `NETWORK`: `testnet`

_Disclaimer_: The DigitalOcean server is publicly accessible on the Internet. Do not put sensitive information on the network that you would not want someone else to know. Anyone with access to the network will be able to use the root account above.

### Building Custom Images

To build a quickstart image with custom or specific versions of stellar-core,
horizon, etc, use the `Makefile`. The following parameters can be specified to
customize the version of each component, and for stellar-core the features it is
built with.

- `TAG`: The docker tag to assign to the build. Default `dev`.
- `CORE_REF`: The git reference of stellar-core to build.
- `CORE_CONFIGURE_FLAGS`: The `CONFIGURE_FLAGS` to configure the stellar-core
  build with. Typically include `--disable-tests`, and to enable the next protocol
  version that is still in development, add
  `--enable-next-protocol-version-unsafe-for-production`.
- `HORIZON_REF`: The git reference of stellar-horizon to build.
- `FRIENDBOT_REF`: The git reference of stellar-friendbot to build.
- `STELLAR_RPC_REF`: The git reference of stellar-rpc to build.

For example:

```
make build \
  TAG=future \
  CORE_REF=... \
  CORE_CONFIGURE_FLAGS=... \
  HORIZON_REF=... \
  FRIENDBOT_REF=... \
  STELLAR_RPC_REF=...
```

### Background vs. Interactive containers

Docker containers can be run interactively (using the `-it` flags) or in a detached, background state (using the `-d` flag). Many of the example commands below use the `-it` flags to aid in debugging but in many cases you will simply want to run a node in the background. It's recommended that you use the use [the tutorials at docker](https://docs.docker.com/engine/tutorials/usingdocker/) to familiarize yourself with using docker.

### Ephemeral mode

Ephermeral mode is provided to support development and testing environments. Every time you start a container in ephemeral mode, the database starts empty and a default configuration file will be used for the appropriate network.

Starting an ephemeral node is simple, just craft a `docker run` command to launch the appropriate image but _do not mount a volume_. To craft your docker command, you need the network name you intend to run against and the flags to expose the ports your want available (See the section named "Ports" below to learn about exposing ports). Thus, launching a testnet node while exposing horizon would be:

```shell
$ docker run --rm -it -p "8000:8000" --name stellar stellar/quickstart --testnet
```

As part of launching, an ephemeral mode container will generate a random password for securing the postgresql service and will output it to standard out. You may use this password (provided you have exposed the postgresql port) to access the running postgresql database (See the section "Accessing Databases" below).

### Persistent mode

In comparison to ephemeral mode, persistent mode is more complicated to operate, but also more powerful. Persistent mode uses a mounted host volume, a directory on the host machine that is exposed to the running docker container, to store all database data as well as the configuration files used for running services. This allows you to manage and modify these files from the host system.

Note that there is no guarantee that the organization of the files of the volume will remain consistent between releases of the image, that occur on every commit to the stellar/quickstart repository. At anytime new files may be added, old files removed, or dependencies and references between them changed. For this reason persistent mode is primarily intended for running short lived test instances for development. If consistency is required over any period of time use [image digest references] to pin to a specific build.

[image digest references]: https://docs.docker.com/engine/reference/run/#imagedigest

Starting a persistent mode container is the same as the ephemeral mode with one exception:

```shell
$ docker run --rm -it -p "8000:8000" -v "/home/scott/stellar:/opt/stellar" --name stellar stellar/quickstart --testnet
```

The `-v` option in the example above tells docker to mount the host directory `/home/scott/stellar` into the container at the `/opt/stellar` path. You may customize the host directory to any location you like, simply make sure to use the same value every time you launch the container. Also note: an absolute directory path is required. The second portion of the volume mount (`/opt/stellar`) should never be changed. This special directory is checked by the container to see if it is mounted from the host system which is used to see if we should launch in ephemeral or persistent mode.

Upon launching a persistent mode container for the first time, the launch script will notice that the mounted volume is empty. This will trigger an interactive initialization process to populate the initial configuration for the container. This interactive initialization adds some complications to the setup process because in most cases you won't want to run the container interactively during normal operation, but rather in the background. We recommend the following steps to setup a persistent mode node:

1.  Run an interactive session of the container at first, ensuring that all services start and run correctly.
2.  Shut down the interactive container (using Ctrl-C).
3.  Start a new container using the same host directory in the background.

## Regarding user accounts

Managing UIDs between a docker container and a host volume can be complicated. At present, this image simply tries to create a UID that does not conflict with the host system by using a preset UID: 10011001. Currently there is no way to customize this value. All data produced in the host volume be owned by 10011001. If this UID value is inappropriate for your infrastructure we recommend you fork this project and do a find/replace operation to change UIDs. We may improve this story in the future if enough users request it.

## Ports

The image exposes one main port through which services provide their APIs:

| Port | Service                         | Description    |
| ---- | ------------------------------- | -------------- |
| 8000 | horizon, stellar-rpc, friendbot | main http port |

The image also exposes a few other ports that most developers do not need, but area available:

| Port  | Service                    | Description          |
| ----- | -------------------------- | -------------------- |
| 5432  | postgresql                 | database access port |
| 6060  | horizon                    | admin port           |
| 6061  | stellar-rpc                | admin port           |
| 11625 | stellar-core               | peer node port       |
| 11626 | stellar-core               | main http port       |
| 11725 | stellar-core (horizon)     | peer node port       |
| 11726 | stellar-core (horizon)     | main http port       |
| 11825 | stellar-core (stellar-rpc) | peer node port       |
| 11826 | stellar-core (stellar-rpc) | main http port       |
| 9001  | supervisord                | supervisord port     |

### Security Considerations

Exposing the network ports used by your running container comes with potential risks. While many attacks are preventable due to the nature of the stellar network, it is extremely important that you maintain protected access to the postgresql server that runs within a quickstart container. An attacker who gains write access to this DB will be able to corrupt your view of the stellar network, potentially inserting fake transactions, accounts, etc.

It is safe to open the horizon http port. Horizon is designed to listen on an internet-facing interface and provides no privileged operations on the port. At the same time admin port should only be exposed to a trusted network, as it provides no security itself.

The HTTP port for stellar-core should only be exposed to a trusted network, as it provides no security itself. An attacker that can make requests to the port will be able to perform administrative commands such as forcing a catchup or changing the logging level and more, many of which could be used to disrupt operations or deny service.

The peer port for stellar-core however can be exposed, and ideally would be routable from the internet. This would allow external peers to initiate connections to your node, improving connectivity of the overlay network. However, this is not required as your container will also establish outgoing connections to peers.

## Accessing and debugging a running container

There will come a time when you want to inspect the running container, either to debug one of the services, to review logs, or perhaps some other administrative tasks. We do this by starting a new interactive shell inside the running container:

```
$ docker exec -it stellar /bin/bash
```

The command above assumes that you launched your container with the name `stellar`; Replace that name with whatever you chose if different. When run, it will open an interactive shell running as root within the container.

### Restarting services

Services within the quickstart container are managed using [supervisord](http://supervisord.org/index.html) and we recommend you use supervisor's shell to interact with running services. To launch the supervisor shell, open an interactive shell to the container and then run `supervisorctl`. You should then see a command prompt that looks like:

```shell
horizon                          RUNNING    pid 143, uptime 0:01:12
postgresql                       RUNNING    pid 126, uptime 0:01:13
stellar-core                     RUNNING    pid 125, uptime 0:01:13
supervisor>
```

From this prompt you can execute any of the supervisord commands:

```shell
# restart horizon
supervisor> restart horizon


# stop stellar-core
supervisor> stop stellar-core
```

You can learn more about what commands are available by using the `help` command.

### Viewing logs

Logs can be found within the container at the path `/var/log/supervisor/`. A file is kept for both the stdout and stderr of the processes managed by supervisord. Additionally, you can use the `tail` command provided by supervisorctl.

Alternatively, to tail all logs into the container's output for all services, append the `--logs` option.

### Accessing databases

The point of this project is to make running stellar's software within your own infrastructure easier, so that your software can more easily integrate with the stellar network. In many cases, you can integrate with horizon's REST API, but often times you'll want direct access to the database either horizon or stellar-core provide. This allows you to craft your own custom sql queries against the stellar network data.

This image manages two postgres databases: `core` for stellar-core's data and `horizon` for horizon's data. The username to use when connecting with your postgresql client or library is `stellar`. The password to use is dependent upon the mode your container is running in: Persistent mode uses a password supplied by you and ephemeral mode generates a password and prints it to the console upon container startup.

## Example launch commands

Below is a list of various ways you might want to launch the quickstart container annotated to illustrate what options are enabled. It's also recommended that you should learn and get familiar with the docker command.

_Launch an ephemeral local only dev/test network:_

```
$ docker run -d -p "8000:8000" --name stellar stellar/quickstart --local
```

_Launch an ephemeral testnet node in the foreground:_

```
$ docker run --rm -it \
    -p "8000:8000" \
    --name stellar \
    stellar/quickstart --testnet
```

_Setup a new persistent node using the host directory `/str`:_

```
$ docker run -it --rm \
    -p "8000:8000" \
    -v "/str:/opt/stellar" \
    --name stellar \
    stellar/quickstart --testnet
```

## Troubleshooting

Let us know what you're having trouble with! Open an issue or join us on our public [Discord server](https://discord.com/invite/stellardev).
