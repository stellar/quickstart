# Stellar Quickstart Docker Image

This project provides a simple way to incorporate stellar-core and horizon into your private infrastructure, provided that you use docker.

This image provide a default, non-validating, ephemeral configuration that should work for most developers.  By configuring a container using this image with a host-based volume (described below in the "Usage" section) an operator gains access to full configuration customization and persistence of data.

The image uses the following software:

- Postgresql 9.6 is used for storing both stellar-core and horizon data
- [stellar-core](https://github.com/stellar/stellar-core)
- [horizon](https://github.com/stellar/horizon)
- Supervisord is used from managing the processes of the services above

## Usage

To use this project successfully, you should first decide a few things:

First, decide whether you want your container to be part of the public, production Stellar network (referred to as the _pubnet_) or the test network (called testnet) that we recommend you use while developing software because you need not worry about losing money on the testnet. Additionally, we have added a standalone network (called standalone) which allows you to run your own private Stellar network. In standalone network mode, you can optionally pass `--protocol-version {version}` parameter to run a specific protocol version (defaults to latest version). You'll provide either `--pubnet`, `--testnet` or `--standalone` as a command line flag when starting the container to determine which network (and base configuration file) to use.

Next, you must decide whether you will use a docker volume or not.  When not using a volume, we say that the container is in _ephemeral mode_, that is, nothing will be persisted between runs of the container. _Persistent mode_ is the alternative, which should be used in the case that you need to either customize your configuration (such as to add a validation seed) or would like avoid a slow catchup to the Stellar network in the case of a crash or server restart.  We recommend persistent mode for anything besides a development or test environment.

Finally, you must decide what ports to expose.  The software in these images listen on 4 ports, each of which you may or may not want to expose to the network your host system is connected to.  A container that exposes no ports isn't very useful, so we recommend at a minimum you expose the horizon http port.  See the "Ports" section below for a more nuanced discussion regarding the decision about what ports to expose.

After deciding on the questions above, you can setup your container.  Please refer to the appropriate section below based upon what mode you will run the container in.

### Background vs. Interactive containers

Docker containers can be run interactively (using the `-it` flags) or in a detached, background state (using the `-d` flag).  Many of the example commands below use the `-it` flags to aid in debugging but in many cases you will simply want to run a node in the background.  It's recommended that you use the use [the tutorials at docker](https://docs.docker.com/engine/tutorials/usingdocker/) to familiarize yourself with using docker.

### Ephemeral mode

Ephermeral mode is provided to support development and testing environments.  Every time you start a container in ephemeral mode, the database starts empty and a default configuration file will be used for the appropriate network.

Starting an ephemeral node is simple, just craft a `docker run` command to launch the appropriate image but *do not mount a volume*.  To craft your docker command, you need the network name you intend to run against and the flags to expose the ports your want available (See the section named "Ports" below to learn about exposing ports).  Thus, launching a testnet node while exposing horizon would be:

```shell
$ docker run --rm -it -p "8000:8000" --name stellar stellar/quickstart --testnet
```  

As part of launching, an ephemeral mode container will generate a random password for securing the postgresql service and will output it to standard out.  You may use this password (provided you have exposed the postgresql port) to access the running postgresql database (See the section "Accessing Databases" below).


### Persistent mode

In comparison to ephemeral mode, persistent mode is more complicated to operate, but also more powerful.  Persistent mode uses a mounted host volume, a directory on the host machine that is exposed to the running docker container, to store all database data as well as the configuration files used for running services.  This allows you to manage and modify these files from the host system.

Starting a persistent mode container is the same as the ephemeral mode with one exception:

```shell
docker run --rm -it -p "8000:8000" -v "/home/scott/stellar:/opt/stellar" --name stellar stellar/quickstart --testnet
```

The `-v` option in the example above tells docker to mount the host directory `/home/scott/stellar` into the container at the `/opt/stellar` path.  You may customize the host directory to any location you like, simply make sure to use the same value every time you launch the container.  Also note: an absolute directory path is required.  The second portion of the volume mount (`/opt/stellar`) should never be changed.  This special directory is checked by the container to see if it is mounted from the host system which is used to see if we should launch in ephemeral or persistent mode.

Upon launching a persistent mode container for the first time, the launch script will notice that the mounted volume is empty.  This will trigger an interactive initialization process to populate the initial configuration for the container.  This interactive initialization adds some complications to the setup process because in most cases you won't want to run the container interactively during normal operation, but rather in the background.  We recommend the following steps to setup a persistent mode node:

1.  Run an interactive session of the container at first, ensuring that all services start and run correctly.
2.  Shut down the interactive container (using Ctrl-C).
3.  Start a new container using the same host directory in the background.


### Customizing configurations

To customize the configurations that both stellar-core and horizon use, you must use persistent mode.  The default configurations will be copied into the data directory upon launching a persistent mode container for the first time.  Use the diagram below to learn about the various configuration files that can be customized.

```
  /opt/stellar
  |-- core                  
  |   `-- etc
  |       `-- stellar-core.cfg  # Stellar core config
  |-- horizon
  |   `-- etc
  |       `-- horizon.env       # A shell script that exports horizon's config
  |-- postgresql
  |   `-- etc
  |       |-- postgresql.conf   # Postgresql root configuration file
  |       |-- pg_hba.conf       # Postgresql client configuration file
  |       `-- pg_ident.conf     # Postgresql user mapping file
  `-- supervisor
      `-- etc
  |       `-- supervisord.conf  # Supervisord root configuration
```

It is recommended that you stop the container before editing any of these files, then restart the container after completing your customization.

*NOTE:* Be wary of editing these files.  It is possible to break the services started within this container with a bad edit.  It's recommended that you learn about managing the operations of each of the services before customizing them, as you are taking responsibility for maintaining those services going forward.


## Regarding user accounts

Managing UIDs between a docker container and a host volume can be complicated.  At present, this image simply tries to create a UID that does not conflict with the host system by using a preset UID:  10011001.  Currently there is no way to customize this value.  All data produced in the host volume be owned by 10011001.  If this UID value is inappropriate for your infrastructure we recommend you fork this project and do a find/replace operation to change UIDs.  We may improve this story in the future if enough users request it.

## Ports

| Port  | Service      | Description          |
|-------|--------------|----------------------|
| 5432  | postgresql   | database access port |
| 8000  | horizon      | main http port       |
| 11625 | stellar-core | peer node port       |
| 11626 | stellar-core | main http port       |


### Security Considerations

Exposing the network ports used by your running container comes with potential risks.  While many attacks are preventable due to the nature of the stellar network, it is extremely important that you maintain protected access to the postgresql server that runs within a quickstart container.  An attacker who gains write access to this DB will be able to corrupt your view of the stellar network, potentially inserting fake transactions, accounts, etc.

It is safe to open the horizon http port.  Horizon is designed to listen on an internet-facing interface and has provides no privileged operations on the port.

The HTTP port for stellar-core should only be exposed to a trusted network, as it provides no security itself.  An attacker that can make requests to the port will be able to perform administrative commands such as forcing a catchup or changing the logging level and more, many of which could be used to disrupt operations or deny service.

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

Logs can be found within the container at the path `/var/log/supervisor/`.  A file is kept for both the stdout and stderr of the processes managed by supervisord.  Additionally, you can use the `tail` command provided by supervisorctl.

### Accessing databases

The point of this project is to make running stellar's software within your own infrastructure easier, so that your software can more easily integrate with the stellar network.  In many cases, you can integrate with horizon's REST API, but often times you'll want direct access to the database either horizon or stellar-core provide.  This allows you to craft your own custom sql queries against the stellar network data.

This image manages two postgres databases:  `core` for stellar-core's data and `horizon` for horizon's data.  The username to use when connecting with your postgresql client or library is `stellar`. The password to use is dependent upon the mode your container is running in:  Persistent mode uses a password supplied by you and ephemeral mode generates a password and prints it to the console upon container startup.


## Example launch commands

Below is a list of various ways you might want to launch the quickstart container annotated to illustrate what options are enabled.  It's also recommended that you should learn and get familiar with the docker command.

*Launch an ephemeral pubnet node in the background:*
```
$ docker run -d -p "8000:8000" --name stellar stellar/quickstart --pubnet
```

*Launch an ephemeral testnet node in the foreground, exposing all ports:*
```
$ docker run --rm -it \
    -p "8000:8000" \
    -p "11626:11626" \
    -p "11625:11625" \
    --name stellar \
    stellar/quickstart --testnet
```

*Setup a new persistent node using the host directory `/str`:*
```
$ docker run -it --rm \
    -v "/str:/opt/stellar" \
    --name stellar \
    stellar/quickstart --pubnet
```

*Start a background persistent container for an already initialized host directory:*
```
$ docker run -d \
    -v "/str:/opt/stellar" \
    -p "8000:8000" \
    --name stellar \
    stellar/quickstart --pubnet
```

## Troubleshooting

Let us know what you're having trouble with!  Open an issue or join us on our public slack channel.
