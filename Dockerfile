FROM ubuntu:18.04

ARG DEBIAN_FRONTEND=noninteractive
RUN chmod 1777 /tmp
RUN apt update -y && apt install -y \
	u-boot-tools \
	cpio \
	gzip \
	device-tree-compiler \
	make \
	git \
	build-essential \
	gcc \
	bison \
	flex \
	python3 \
	python3-distutils \
	python3-dev \
	swig \
	python \
	python-dev \
	bc \
	ash \
	curl \
	gnat-5 \
	libncurses5-dev \
	m4 \
	zlib1g-dev \
  && rm -rf /var/lib/apt/lists/*

RUN /bin/ash -c 'set -ex && \
    ARCH=`uname -m` && \
    if [ "$ARCH" != "aarch64" ]; then \
	echo "x86_64" && \
	apt update -y && \
	apt install -y gcc-aarch64-linux-gnu; \
    fi'

WORKDIR /build
VOLUME /out

ARG DISTRO
ENV DISTRO=${DISTRO}
ENV CROSS_COMPILE=aarch64-linux-gnu-
ENV ARCH=arm64
ARG CPUS=2
ENV CPUS=${CPUS}

COPY . /build