FROM ubuntu:zesty
RUN apt-get -y update
RUN apt-get -y install protobuf-compiler git make file