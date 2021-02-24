# L4T Bootstack

This repository contains our L4T u-boot, u-boot scripts, the latest coreboot.rom and a script to update it.

## Usage

```
Usage: ./build [OPTIONS] <output_directory>
Build switch bootfiles

-h, --help				Display help
-c, --coreboot			Build coreboot only
-d, --distro			Set distribution name
-n, --nocomp			Build without compressing files
-p, --patch				Apply coreboot RAM overclock patch
-u, --uboot				Set uboot branch
-v, --verbose			Run script in verbose mode. Will print out each step of execution.
```

Available environment variables :
```
ARCH=<default: arm64>
COREBOOT=<default: false> - equivalent to -c, --coreboot
CROSS_COMPILE=<default: aarch64-linux-gnu->
CPUS=<default: all - 1>
DISTRO=<represent the switchroot/<distribution> name> - equivalent to -d, --distro
NO_COMPRESS=<default: false> - equivalent to -n, --nocomp
PATCH=<default: false> - equivalent to -p, --patch
UBOOT=<default: linux-norebase> - equivalent to  -u, --uboot
```

## Automated build

Run the docker container to trigger the actual build (example using focal) `./out/` directory will be created and will store the build artifacts :

```sh
docker run -it --rm -e CPUS=$(nproc) -e DISTRO=focal -v "${PWD}"/out:/out registry.gitlab.com/switchroot/bootstack/bootstack-build-scripts
```
