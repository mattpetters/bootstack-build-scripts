FROM ubuntu:jammy

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
	python-is-python3 \
	swig \
	python2-dev \
	python2 \
	bc \
	curl \
	libncurses5-dev \
	m4 \
	zlib1g-dev \
	p7zip-full \
	wget \
    acpica-tools \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /build
VOLUME /out

ARG DISTRO
ENV DISTRO=${DISTRO}

COPY . /build
CMD ./build.sh /out
