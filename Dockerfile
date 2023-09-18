ARG STELLAR_CORE_IMAGE_REF
ARG HORIZON_IMAGE_REF
ARG FRIENDBOT_IMAGE_REF
ARG SOROBAN_RPC_IMAGE_REF

FROM $STELLAR_CORE_IMAGE_REF AS stellar-core
FROM $HORIZON_IMAGE_REF AS horizon
FROM $FRIENDBOT_IMAGE_REF AS friendbot
FROM $SOROBAN_RPC_IMAGE_REF AS soroban-rpc

FROM ubuntu:22.04

EXPOSE 5432
EXPOSE 8000
EXPOSE 6060
EXPOSE 6061
EXPOSE 11625
EXPOSE 11626

ADD dependencies /
RUN /dependencies

COPY --from=stellar-core /usr/local/bin/stellar-core /usr/bin/stellar-core

COPY --from=horizon /go/bin/horizon /usr/bin/stellar-horizon

COPY --from=friendbot /app/friendbot /usr/local/bin/friendbot

COPY --from=soroban-rpc /bin/soroban-rpc /usr/bin/stellar-soroban-rpc

RUN adduser --system --group --quiet --home /var/lib/stellar --disabled-password --shell /bin/bash stellar;

RUN ["mkdir", "-p", "/opt/stellar"]
RUN ["touch", "/opt/stellar/.docker-ephemeral"]

RUN ["ln", "-s", "/opt/stellar", "/stellar"]
RUN ["ln", "-s", "/opt/stellar/core/etc/stellar-core.cfg", "/stellar-core.cfg"]
RUN ["ln", "-s", "/opt/stellar/horizon/etc/horizon.env", "/horizon.env"]
ADD common /opt/stellar-default/common
ADD local /opt/stellar-default/local
ADD pubnet /opt/stellar-default/pubnet
ADD testnet /opt/stellar-default/testnet
ADD futurenet /opt/stellar-default/futurenet


ADD start /
RUN ["chmod", "+x", "start"]

ENTRYPOINT ["/start"]
