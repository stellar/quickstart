ARG XDR_IMAGE_REF
ARG CORE_IMAGE_REF
ARG HORIZON_IMAGE_REF
ARG FRIENDBOT_IMAGE_REF
ARG RPC_IMAGE_REF
ARG LAB_IMAGE_REF

FROM $XDR_IMAGE_REF AS xdr
FROM $CORE_IMAGE_REF AS core
FROM $HORIZON_IMAGE_REF AS horizon
FROM $FRIENDBOT_IMAGE_REF AS friendbot
FROM $RPC_IMAGE_REF AS rpc
FROM $LAB_IMAGE_REF AS lab

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
