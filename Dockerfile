# The base images in this Dockerfile attempt to align on the same underlying
# version of Debian. This is not strictly required but it is a simple narrative
# for keeping images updated. Updates to the underlying OS are primarily driven
# by the versions of Ubuntu that stellar-core is supported and tested on.
#
# The base images used in this image are:
#
# | Base Image             | Debian Version |
# |------------------------|----------------|
# | ubuntu:24.04           | 13 (trixie)    |
# | rust:1-trixie          | 13 (trixie)    |
# | golang:1.24-trixie     | 13 (trixie)    |
# | node:22-trixie         | 13 (trixie)    |

ARG XDR_IMAGE=stellar-xdr-stage
ARG CORE_IMAGE=stellar-core-stage
ARG HORIZON_IMAGE=stellar-horizon-stage
ARG FRIENDBOT_IMAGE=stellar-friendbot-stage
ARG RPC_IMAGE=stellar-rpc-stage
ARG LAB_IMAGE=stellar-lab-stage
ARG GALEXIE_IMAGE=stellar-galexie-stage

# xdr

FROM rust:1-trixie AS stellar-xdr-builder
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

FROM ubuntu:24.04 AS stellar-core-builder

ENV DEBIAN_FRONTEND=noninteractive
COPY apt-retry /usr/local/bin/
RUN apt-retry sh -c 'apt-get update && \
    apt-get -y install iproute2 procps lsb-release \
                       git build-essential pkg-config autoconf automake libtool \
                       bison flex sed perl libpq-dev parallel \
                       clang-20 libc++abi-20-dev libc++-20-dev \
                       postgresql curl jq'

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

ARG CC=clang-20
ARG CXX=clang++-20
ARG CFLAGS='-O3 -g1 -fno-omit-frame-pointer'
ARG CXXFLAGS='-O3 -g1 -fno-omit-frame-pointer -stdlib=libc++'

RUN sysctl vm.mmap_rnd_bits=28

RUN ./autogen.sh
RUN ./install-rust.sh
ENV PATH "/root/.cargo/bin:$PATH"
RUN sh -c './configure CC="${CC}" CXX="${CXX}" CFLAGS="${CFLAGS}" CXXFLAGS="${CXXFLAGS}" $(cat /tmp/arg_configure_flags)'
RUN sh -c 'make -j $(nproc)'
RUN make install

FROM scratch AS stellar-core-stage

COPY --from=stellar-core-builder /usr/local/bin/stellar-core /stellar-core

# rpc

FROM golang:1.24-trixie AS stellar-rpc-builder

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

COPY apt-retry /usr/local/bin/
RUN apt-retry sh -c 'apt-get update && apt-get install -y build-essential jq' && apt-get clean
RUN curl https://sh.rustup.rs -sSf | sh -s -- -y --default-toolchain $RUST_TOOLCHAIN_VERSION

RUN make build-stellar-rpc

FROM scratch AS stellar-rpc-stage

COPY --from=stellar-rpc-builder /go/src/github.com/stellar/stellar-rpc/stellar-rpc /stellar-rpc

# horizon

FROM golang:1.24-trixie AS stellar-horizon-builder

ENV DEBIAN_FRONTEND=noninteractive
COPY apt-retry /usr/local/bin/
RUN apt-retry sh -c 'apt-get update && apt-get -y install jq'

ARG HORIZON_REPO
ARG HORIZON_REF
ARG HORIZON_OPTIONS
RUN echo "$HORIZON_OPTIONS" | jq -r '.pkg // ""' > /tmp/arg_pkg

WORKDIR /src
RUN git clone https://github.com/${HORIZON_REPO} /src
RUN git fetch origin ${HORIZON_REF}
RUN git checkout ${HORIZON_REF}
ENV CGO_ENABLED=0
ENV GOFLAGS="-ldflags=-X=github.com/stellar/go/support/app.version=${HORIZON_REF}-(built-from-source)"
RUN go build -o /stellar-horizon $(cat /tmp/arg_pkg)

FROM scratch AS stellar-horizon-stage

COPY --from=stellar-horizon-builder /stellar-horizon /stellar-horizon

# friendbot

FROM golang:1.24-trixie AS stellar-friendbot-builder

ENV DEBIAN_FRONTEND=noninteractive
COPY apt-retry /usr/local/bin/
RUN apt-retry sh -c 'apt-get update && apt-get -y install jq'

ARG FRIENDBOT_REPO
ARG FRIENDBOT_REF
ARG FRIENDBOT_OPTIONS
RUN echo "$FRIENDBOT_OPTIONS" | jq -r '.pkg // ""' > /tmp/arg_pkg

WORKDIR /src
RUN git clone https://github.com/${FRIENDBOT_REPO} /src
RUN git fetch origin ${FRIENDBOT_REF}
RUN git checkout ${FRIENDBOT_REF}
ENV CGO_ENABLED=0
ENV GOFLAGS="-ldflags=-X=github.com/stellar/go/support/app.version=${FRIENDBOT_REF}-(built-from-source)"
RUN go build -o /friendbot $(cat /tmp/arg_pkg)

FROM scratch AS stellar-friendbot-stage

COPY --from=stellar-friendbot-builder /friendbot /friendbot

# lab

FROM node:22-trixie AS stellar-lab-builder

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

# galexie

FROM golang:1.24-trixie AS stellar-galexie-builder

ARG GALEXIE_REPO
ARG GALEXIE_REF

WORKDIR /src
RUN git clone https://github.com/${GALEXIE_REPO} /src
RUN git fetch origin ${GALEXIE_REF}
RUN git checkout ${GALEXIE_REF}
ENV CGO_ENABLED=0
RUN go build -o /galexie .

FROM scratch AS stellar-galexie-stage

COPY --from=stellar-galexie-builder /galexie /galexie

# quickstart

FROM $XDR_IMAGE AS xdr
FROM $CORE_IMAGE AS core
FROM $HORIZON_IMAGE AS horizon
FROM $FRIENDBOT_IMAGE AS friendbot
FROM $RPC_IMAGE AS rpc
FROM $LAB_IMAGE AS lab
FROM $GALEXIE_IMAGE AS galexie

FROM ubuntu:24.04 AS quickstart

ARG REVISION
ENV REVISION=$REVISION

ARG IMAGE_NAME
ENV IMAGE_NAME=$IMAGE_NAME

EXPOSE 5432
EXPOSE 6060
EXPOSE 6061
EXPOSE 8000
EXPOSE 8002
EXPOSE 8100
EXPOSE 11625
EXPOSE 11626

COPY apt-retry /usr/local/bin/
ADD dependencies /
RUN /dependencies

COPY --from=xdr /stellar-xdr /usr/local/bin/stellar-xdr
COPY --from=core /stellar-core /usr/bin/stellar-core
COPY --from=horizon /stellar-horizon /usr/bin/stellar-horizon
COPY --from=friendbot /friendbot /usr/local/bin/friendbot
COPY --from=rpc /stellar-rpc /usr/bin/stellar-rpc
COPY --from=lab /lab /opt/stellar/lab
COPY --from=lab /node /usr/bin/
COPY --from=galexie /galexie /usr/bin/galexie

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

ENTRYPOINT ["/start"]
