FROM ubuntu:18.04
#FROM alpine:latest
#FROM golang:1.13-alpine as builder

MAINTAINER Energi Core Team <support@energi.team>

USER root
RUN apt-get update
RUN apt-get upgrade -y
RUN apt-get install wget curl -y
RUN apt-get install -y x11vnc xvfb
RUN mkdir ~/.vnc

# Setup a password
RUN x11vnc -storepasswd 1234 ~/.vnc/passwd

#RUN apk add --no-cache bash

#RUN mkdir -p /root/energi3/bin
#RUN mkdir -p energi3/js
#RUN mkdir -p energi3/.safe
#RUN mkdir -p energi3/etc

# Pull all binaries into a second stage deploy alpine container

RUN wget https://raw.githack.com/zalam003/EnergiCore3/master/publictest/scripts/pubtest_install_linux.sh
RUN /bin/bash pubtest_install_linux.sh
RUN rm pubtest_install_linux.sh

WORKDIR /root/energi3/bin
RUN ls -l
#RUN ./run_linux.sh
# Autostart firefox (might not be the best way, but it does the trick)
RUN bash -c 'echo "/root/energi3/bin/energi3-linux-amd64 --testnet console" >> /.bashrc'
#RUN ./energi3-linux-amd64 --testnet console

#EXPOSE 49795 49796 49797 49797/udp
EXPOSE 5900
CMD    ["x11vnc", "-forever", "-usepw", "-create"]
