FROM stellar/base:latest

MAINTAINER Bartek Nowotarski <bartek@stellar.org>

ENV STELLAR_CORE_VERSION 0.4.1-291-657d67b8

EXPOSE 5432 8000 8080

ADD dependencies /
RUN ["chmod", "+x", "dependencies"]
RUN /dependencies

ADD install /
RUN ["chmod", "+x", "install"]
RUN /install

ADD start stellar-core.cfg /
RUN ["chmod", "+x", "start"]
CMD /start
