ARG XDR_IMAGE=stellar-xdr-stage
ARG CORE_IMAGE=stellar-core-stage
ARG HORIZON_IMAGE=stellar-horizon-stage
ARG FRIENDBOT_IMAGE=stellar-friendbot-stage
ARG RPC_IMAGE=stellar-rpc-stage
ARG LAB_IMAGE=stellar-lab-stage

# xdr

FROM rust AS stellar-xdr-builder
ARG XDR_REPO
ARG XDR_REF
WORKDIR /wd
RUN git clone https://github.com/${XDR_REPO} /wd
RUN git fetch origin ${XDR_REF}
RUN git checkout ${XDR_REF}
RUN rustup show active-toolchain || rustup toolchain install
RUN cargo install stellar-xdr --features cli --path . --locked

FROM scratch AS stellar-xdr-stage

COPY --from=stellar-xdr-builder /usr/local/cargo/bin/stellar-xdr /stellar-xdr

# core

FROM ubuntu:focal AS stellar-core-builder

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && \
    apt-get -y install iproute2 procps lsb-release \
                       git build-essential pkg-config autoconf automake libtool \
                       bison flex sed perl libpq-dev parallel libunwind-dev \
                       clang-12 libc++abi-12-dev libc++-12-dev \
                       postgresql curl jq

ARG CORE_REPO
ARG CORE_REF
ARG CORE_OPTIONS
RUN echo "$CORE_OPTIONS" | jq -r '.configure_flags // ""' > /tmp/arg_configure_flags

WORKDIR /wd
RUN git clone https://github.com/${CORE_REPO} /wd
RUN git fetch origin ${CORE_REF}
RUN git checkout ${CORE_REF}

RUN git clean -dXf
RUN git submodule foreach --recursive git clean -dXf

ARG CC=clang-12
ARG CXX=clang++-12
ARG CFLAGS='-O3 -g1 -fno-omit-frame-pointer'
ARG CXXFLAGS='-O3 -g1 -fno-omit-frame-pointer -stdlib=libc++'

RUN sysctl vm.mmap_rnd_bits=28

RUN ./autogen.sh
RUN ./install-rust.sh
ENV PATH "/root/.cargo/bin:$PATH"
RUN sh -c './configure CC="${CC}" CXX="${CXX}" CFLAGS="${CFLAGS}" CXXFLAGS="${CXXFLAGS}" $(</tmp/arg_configure_flags)'
RUN sh -c 'make -j $(nproc)'
RUN make install

FROM scratch AS stellar-core-stage

COPY --from=stellar-core-builder /usr/local/bin/stellar-core /stellar-core

# rpc

FROM golang:1.24-bullseye AS stellar-rpc-builder

ARG RPC_REPO
ARG RPC_REF
ARG RUST_TOOLCHAIN_VERSION=stable

WORKDIR /go/src/github.com/stellar/stellar-rpc
RUN git clone https://github.com/${RPC_REPO} /go/src/github.com/stellar/stellar-rpc
RUN git fetch origin ${RPC_REF}
RUN git checkout ${RPC_REF}

ENV CARGO_HOME=/rust/.cargo
ENV RUSTUP_HOME=/rust/.rust
ENV PATH="/usr/local/go/bin:$CARGO_HOME/bin:${PATH}"
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y build-essential && apt-get clean
RUN curl https://sh.rustup.rs -sSf | sh -s -- -y --default-toolchain $RUST_TOOLCHAIN_VERSION

RUN make build-stellar-rpc

FROM scratch AS stellar-rpc-stage

COPY --from=stellar-rpc-builder /go/src/github.com/stellar/stellar-rpc/stellar-rpc /stellar-rpc

# horizon

FROM golang:1.23 AS stellar-horizon-builder

ARG HORIZON_REPO
ARG HORIZON_REF
WORKDIR /go/src/github.com/stellar/go
RUN git clone https://github.com/${HORIZON_REPO} /go/src/github.com/stellar/go
RUN git fetch origin ${HORIZON_REF}
RUN git checkout ${HORIZON_REF}
ENV CGO_ENABLED=0
ENV GOFLAGS="-ldflags=-X=github.com/stellar/go/support/app.version=${HORIZON_REF}-(built-from-source)"
RUN go install github.com/stellar/go/services/horizon

FROM scratch AS stellar-horizon-stage

COPY --from=stellar-horizon-builder /go/bin/horizon /horizon

# friendbot

FROM golang:1.23 AS stellar-friendbot-builder

ARG FRIENDBOT_REPO
ARG FRIENDBOT_REF
WORKDIR /go/src/github.com/stellar/go
RUN git clone https://github.com/${FRIENDBOT_REPO} /go/src/github.com/stellar/go
RUN git fetch origin ${FRIENDBOT_REF}
RUN git checkout ${FRIENDBOT_REF}
ENV CGO_ENABLED=0
ENV GOFLAGS="-ldflags=-X=github.com/stellar/go/support/app.version=${FRIENDBOT_REF}-(built-from-source)"
RUN go install github.com/stellar/go/services/friendbot

FROM scratch AS stellar-friendbot-stage

COPY --from=stellar-friendbot-builder /go/bin/friendbot /friendbot

# lab

FROM node:22 AS stellar-lab-builder

ARG LAB_REPO
ARG LAB_REF
ENV NEXT_TELEMETRY_DISABLED=1
ENV PORT=8100
WORKDIR /lab
RUN git clone https://github.com/${LAB_REPO} /lab
RUN git fetch origin ${LAB_REF}
RUN git checkout ${LAB_REF}
RUN rm -rf .git
RUN corepack enable
RUN pnpm install --frozen-lockfile
ENV NEXT_PUBLIC_COMMIT_HASH=${LAB_REF}
ENV NEXT_PUBLIC_ENABLE_STANDALONE_OUTPUT=true
ENV NEXT_PUBLIC_ENABLE_EXPLORER=true
ENV NEXT_PUBLIC_DEFAULT_NETWORK=custom
ENV NEXT_PUBLIC_RESOURCE_PATH=/lab
ENV NEXT_BASE_PATH=/lab
RUN pnpm build

FROM scratch AS stellar-lab-stage

COPY --from=stellar-lab-builder /lab/build/standalone /lab
COPY --from=stellar-lab-builder /lab/public /lab/public
COPY --from=stellar-lab-builder /lab/build/static /lab/public/_next/static
COPY --from=stellar-lab-builder /usr/local/bin/node /node

# quickstart

FROM $XDR_IMAGE AS xdr
FROM $CORE_IMAGE AS core
FROM $HORIZON_IMAGE AS horizon
FROM $FRIENDBOT_IMAGE AS friendbot
FROM $RPC_IMAGE AS rpc
FROM $LAB_IMAGE AS lab

FROM ubuntu:22.04

ARG REVISION
ENV REVISION=$REVISION

EXPOSE 5432
EXPOSE 6060
EXPOSE 6061
EXPOSE 8000
EXPOSE 8002
EXPOSE 8100
EXPOSE 11625
EXPOSE 11626

ADD dependencies /
RUN /dependencies

COPY --from=xdr /stellar-xdr /usr/local/bin/stellar-xdr
COPY --from=core /stellar-core /usr/bin/stellar-core
COPY --from=horizon /horizon /usr/bin/stellar-horizon
COPY --from=friendbot /friendbot /usr/local/bin/friendbot
COPY --from=rpc /stellar-rpc /usr/bin/stellar-rpc
COPY --from=lab /lab /opt/stellar/lab
COPY --from=lab /node /usr/bin/

RUN adduser --system --group --quiet --home /var/lib/stellar --disabled-password --shell /bin/bash stellar;

RUN ["mkdir", "-p", "/opt/stellar"]
RUN ["touch", "/opt/stellar/.docker-ephemeral"]

ADD .image.json /image.json

RUN ["rm", "-fr", "/etc/supervisor"]
RUN ["ln", "-sT", "/opt/stellar/supervisor/etc", "/etc/supervisor"]

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


ARG PROTOCOL_VERSION_DEFAULT
RUN test -n "$PROTOCOL_VERSION_DEFAULT" || (echo "Image build arg PROTOCOL_VERSION_DEFAULT required and not set" && false)
ENV PROTOCOL_VERSION_DEFAULT=$PROTOCOL_VERSION_DEFAULT

ENTRYPOINT ["/start"]
