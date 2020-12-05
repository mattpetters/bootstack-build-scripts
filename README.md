# L4T Bootstack

This repository contains our L4T u-boot, u-boot scripts, the latest coreboot.rom and a script to update it.

## Automated build

Run the docker container to trigger the actual build (example using focal) `./out/` directory will be created and will store the build artifacts :
```sh
docker run -it --rm -e CPUS=$(nproc) -e DISTRO=focal -v "${PWD}"/out:/out alizkan/l4t-bootfiles-misc:latest
```