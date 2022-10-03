ARG STELLAR_CORE_VERSION=19.4.0-1075.39bee1a2b.focal
ARG HORIZON_VERSION=2.20.0-296
ARG FRIENDBOT_VERSION=horizon-v2.20.0
# TODO, when soroban-rpc is released
# ARG SOROBAN_RPC_VERSION=x.y.z - this may be same version as horizon

FROM golang:1.19 as go

ARG FRIENDBOT_VERSION
#ARG SOROBAN_RPC_VERSION

RUN go install github.com/stellar/go/services/friendbot@$FRIENDBOT_VERSION
# TODO, when horizon released with p20/soroban support
#RUN go install github.com/stellar/go/exp/services/soroban-rpc@$SOROBAN_RPC_VERSION

FROM ubuntu:20.04

ARG STELLAR_CORE_VERSION
ARG HORIZON_VERSION

EXPOSE 5432
EXPOSE 8000
EXPOSE 6060
EXPOSE 11625
EXPOSE 11626

ADD dependencies /
RUN ["chmod", "+x", "dependencies"]
RUN /dependencies

ADD install /
RUN ["chmod", "+x", "install"]
RUN /install
COPY --from=go /go/bin/friendbot /usr/local/bin/friendbot
# TODO, when horizon released with p20/soroban support
#COPY --from=go /go/bin/soroban-rpc /usr/local/bin/soroban-rpc

RUN ["mkdir", "-p", "/opt/stellar"]
RUN ["touch", "/opt/stellar/.docker-ephemeral"]

RUN ["ln", "-s", "/opt/stellar", "/stellar"]
RUN ["ln", "-s", "/opt/stellar/core/etc/stellar-core.cfg", "/stellar-core.cfg"]
RUN ["ln", "-s", "/opt/stellar/horizon/etc/horizon.env", "/horizon.env"]
ADD common /opt/stellar-default/common
ADD pubnet /opt/stellar-default/pubnet
ADD testnet /opt/stellar-default/testnet
ADD standalone /opt/stellar-default/standalone


ADD start /
RUN ["chmod", "+x", "start"]

ENTRYPOINT ["/start"]
