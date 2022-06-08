ARG STELLAR_CORE_VERSION=19.1.0-943.e801fd93b.focal
ARG HORIZON_VERSION=2.17.1-282
ARG FRIENDBOT_VERSION=horizon-v2.17.1

FROM golang:1.17 as go

ARG FRIENDBOT_VERSION

RUN go install github.com/stellar/go/services/friendbot@$FRIENDBOT_VERSION

FROM ubuntu:20.04

MAINTAINER Bartek Nowotarski <bartek@stellar.org>

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
