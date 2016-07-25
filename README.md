# Stellar Quickstart Docker Image

This project provides a simple way to incorporate stellar-core and horizon into your private infrastructure, provided that you use docker. This project produces two separate docker images: `stellar/quickstart:pubnet` and `stellar/quickstart:testnet`, each of which is configured to join the public network or the test network.

These images provide a default, non-validating, ephemeral configuration that should work for most developers.  By configuring a container using this image with a host-based volume (described below in the "Usage" section) an operator gains access to full configuration customization and persistence of data.

The images produces by this project run the following software:

- Postgresql 9.5 is used for storing both stellar-core and horizon data
- [stellar-core](https://github.com/stellar/stellar-core)
- [horizon](https://github.com/stellar/horizon)
- Supervisord is used from managing the processes of the services above.

## Usage

To use this project successfully, you should first decide a few things:

First, decide whether you want your container to be part of the public, production stellar network (referred to as the _pubnet_) or the test network (called testnet) that we recommend you use while developing software because you need not worry about losing money on the testnet.  This decision will inform what docker image to use: `stellar/quickstart:pubnet` or `stellar/quickstart:testnet`, respectively.

Next, you must decide whether you will use a docker volume or not.  When not using a volume, we say that the container is in _ephemeral mode_, that is, nothing will be persisted between runs of the container. _Persistent mode_ is the alternative, which should be used the case that you need to either customize your configuration (such as to add a validation seed) or would like avoid a slow catchup to the stellar network in the case of a crash or server restart.  We recommend persistent mode for anything besides a development or test environment.

Finally, you must decide what ports to expose.  This software that runs within these images listen on 4 ports, each of which you may or may not want tox` expose to the network your host system is connected to.  A container that exposes no ports isn't very useful, so we recommend at a minimum you expose the horizon http port.  See the "Ports" section below for a more nuanced discussion regarding the decision about what ports to expose.

After deciding on the questions above, you can setup your container.  Please refer to the appropriate section below based upon what mode you will run the container in.

### Ephemeral mode

Ephermeral mode is provided to support development and testing environments.  Every time you start a container in ephemeral mode, the database starts in a blank slate and a default configuration file will be used for the appropriate network.

Starting an ephemeral node is simple, just craft a `docker run` command to launch the appropriate image but *do not mount a volume*.  To craft your docker command, you need the image name and the flags to expose the ports your want available (See the sections named "Ports" below to learn about exposing ports).  Thus, launching a testnet node while exposing horizon would be:

```shell
$ docker run --rm -it -p "8000:8000" --name stellar stellar/quickstart:testnet
```  

As part of launching, an ephemeral mode container will generate a random password for securing the postgresql service and will output it to standard out.  You may use this password (provided you have exposed the postgresql port) to access the running postgresql database (See the section "Accessing Databases" below).


### Persistent mode

In comparison to ephemeral mode, persistent mode is more complicated to operate, but also more powerful.  Persistent mode uses a mounted host volume, a directory on the host machine that is exposed to the running docker container, to store all database data as well as the configuration files used for running services.  This allows you to manage and modify these files from the host system.

Starting a persistent mode container is the same as the ephemeral mode with one exception:

```shell
docker run --rm -it -p "8000:8000" -v "~/stellar:/opt/stellar" --name stellar stellar/quickstart:testnet
```

The `-v` option in the example above tells docker to mount the host directory `~/stellar` into the container at the `/opt/stellar` path.  You may customize the host directory to any location you like, simply make sure to use the same value every time you launch the container.  The second portion of the volume mount (`/opt/stellar`) should never be changed.  This special directory is checked by the container to see if it is mounted from the host system which is used to see if we should launch in ephemeral or persistent mode.

Upon launching a persistent mode container for the first time, the launch script will notice that the mounted volume is empty.  This will trigger an interactive initialization process to populate the initial configuration for the container.  

### Customizing configurations

To customize the configurations that both stellar-core and horizon use, you must use persistent mode.  The default configurations will be copied into the data directory upon launching a persistent mode container for the first time.  


## Ports

| Port  | Service      | Description          |
|-------|--------------|----------------------|
| 5432  | postgresql   | database access port |
| 8000  | horizon      | main http port       |
| 11625 | stellar-core | main http port       |
| 11626 | stellar-core | peer node port       |


### Security Considerations

Exposing the network ports used by your running container comes with potential risks.  While many attacks are preventable due to the nature of the stellar network, it is extremely important that you maintain protected access to the postgresql server that runs within a quickstart container.  An attacker who gains write access to this DB will be able to corrupt your view of the stellar network, potentially inserting fake transactions, accounts, etc.

It is safe to open the horizon http port.  Horizon is designed to listen on an internet-facing interface and has provides no privileged operations on the port.

The HTTP port for stellar-core should only be exposed to a trusted network, as it provides no security itself.  An attacker that can make requests to the port will be able to perform administrative commands such as forcing a catchup or changing the logging level and more, many of which could be used to distrupt operations or deny service.

The peer port for stellar-core however can be exposed, and ideally would be routable from the internet.  This would allow external peers to initiate connections to your node, improving connectivity of the overlay network.  However, this is not required as your container will also establish outgoing connections to peers.

## Accessing and debugging a running container

There will come a time when you want to inspect the running container, either to debug one of the services, to review logs, or perhaps some other administrative tasks.  We do this by starting a new interactive shell inside the running container:

```
$ docker exec -it stellar /bin/bash
```

The command above assumes that you launched your container with the name `stellar`; Replace that name with whatever you chose if different.  When run, it will open an interactive shell running as root within the container.

### Restarting services

Services within the quickstart container are managed using [supervisord](http://supervisord.org/index.html) and we recommend you use supervisor's shell to interact with running services.  To launch the supervisor shell, open an interactive shell to the container and then run `supervisorctl`.  You should then see a command prompt that looks like:

```shell
supervisor>
```

From this prompt you can execute any of the supervisord commands:  TODO

### Viewing logs

TODO

### Accessing databases

TODO


## Example launch commands

Below is a list of various ways you might want to launch the quickstart container annotated to illustrate what options are enabled.

TODO


## Troubleshooting

TODO
