ARG STELLAR_XDR_IMAGE_REF
ARG STELLAR_CORE_IMAGE_REF
ARG HORIZON_IMAGE_REF
ARG FRIENDBOT_IMAGE_REF
ARG STELLAR_RPC_IMAGE_REF
ARG LAB_IMAGE_REF

FROM $STELLAR_XDR_IMAGE_REF AS stellar-xdr
FROM $STELLAR_CORE_IMAGE_REF AS stellar-core
FROM $HORIZON_IMAGE_REF AS horizon
FROM $FRIENDBOT_IMAGE_REF AS friendbot
FROM $STELLAR_RPC_IMAGE_REF AS stellar-rpc
FROM $LAB_IMAGE_REF AS lab

FROM ubuntu:22.04

ARG REVISION
ENV REVISION $REVISION

EXPOSE 5432
EXPOSE 6060
EXPOSE 6061
EXPOSE 8000
EXPOSE 8002
EXPOSE 8004
EXPOSE 8100
EXPOSE 11625
EXPOSE 11626

ADD dependencies /
RUN /dependencies

COPY --from=stellar-xdr /usr/local/cargo/bin/stellar-xdr /usr/local/bin/stellar-xdr
COPY --from=stellar-core /usr/local/bin/stellar-core /usr/bin/stellar-core
COPY --from=horizon /go/bin/horizon /usr/bin/stellar-horizon
COPY --from=friendbot /app/friendbot /usr/local/bin/friendbot
COPY --from=stellar-rpc /bin/stellar-rpc /usr/bin/stellar-rpc
COPY --from=lab /lab /opt/stellar/lab
COPY --from=lab /usr/local/bin/node \
                /usr/local/bin/npm \
                /usr/local/bin/corepack \
                /usr/local/bin/npx \
                /usr/local/bin/yarn \
                /usr/local/bin/yarnpkg \
                /usr/bin/
COPY --from=lab /usr/local/include/node /usr/local/include/node
COPY --from=lab /usr/local/lib/node_modules /usr/local/lib/node_modules

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

ARG PROTOCOL_VERSION_DEFAULT
RUN test -n "$PROTOCOL_VERSION_DEFAULT" || (echo "Image build arg PROTOCOL_VERSION_DEFAULT required and not set" && false)
ENV PROTOCOL_VERSION_DEFAULT $PROTOCOL_VERSION_DEFAULT

ENTRYPOINT ["/start"]
