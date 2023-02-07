# syntax=docker/dockerfile:1

ARG OS
FROM ghcr.io/linuxserver/baseimage-alpine:${OS}

# set version label
ARG BUILD_DATE
ARG VERSION
ARG OS
LABEL build_version="ImageGenius version:- ${VERSION} Build-date:- ${BUILD_DATE}"
LABEL maintainer="hydazz"

RUN \
  curl -o \
    /etc/apk/keys/ig.rsa.pub \
    "https://packages.imagegenius.io/ig.rsa.pub" && \
  echo "https://packages.imagegenius.io/v${OS}/" >>/etc/apk/repositories

# add local files
COPY root/ /
