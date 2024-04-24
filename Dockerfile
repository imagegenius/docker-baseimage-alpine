# syntax=docker/dockerfile:1

FROM ghcr.io/linuxserver/baseimage-alpine:3.19

# set version label
ARG BUILD_DATE
ARG VERSION
LABEL build_version="ImageGenius version:- ${VERSION} Build-date:- ${BUILD_DATE}"
LABEL maintainer="hydazz"

RUN \
  curl -o \
    /etc/apk/keys/ig.rsa.pub \
    "https://packages.imagegenius.io/ig.rsa.pub" && \
  echo "https://packages.imagegenius.io/v3.19/" >>/etc/apk/repositories

# add local files
COPY root/ /
