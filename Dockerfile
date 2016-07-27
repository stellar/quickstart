FROM stellar/base:latest

# NOTE:  This dockerfile is for the base quickstart image, of which two
# derivatives are created (the testnet and pubnet images).  Images built from
# this dockerfile aren't intended to be used directly.  See testnet/Dockerfile
# or pubnet/Dockerfile for details on how those images are built.

MAINTAINER Bartek Nowotarski <bartek@stellar.org>

ENV STELLAR_CORE_VERSION 0.5.0-295-19f29054
ENV HORIZON_VERSION 0.5.0

EXPOSE 5432
EXPOSE 8000
EXPOSE 11625
EXPOSE 11626

ADD dependencies /
RUN ["chmod", "+x", "dependencies"]
RUN /dependencies

ADD install /
RUN ["chmod", "+x", "install"]
RUN /install

# create home for data and config
RUN ["mkdir", "-p", "/opt/stellar"]
RUN ["mkdir", "-p", "/opt/stellar-default"]
RUN ["touch", "/opt/stellar/.docker-ephemeral"]
ADD postgresql /opt/stellar-default/postgresql/etc
ADD supervisor /opt/stellar-default/supervisor/etc


ADD start /
RUN ["chmod", "+x", "start"]

CMD ["/init", "--", "/bin/bash", "/start" ]
