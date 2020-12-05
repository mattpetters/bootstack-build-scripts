#!/bin/bash
out=$(realpath "${@:$#}")
scripts_dir="$(dirname "$(dirname "$(dirname "${BASH_SOURCE[0]}")")")"/src/uboot-scripts

[[ ! -d "${out}" ]] && \
	echo "${out} is not a valid directory! Exiting.." && exit 1

[[ -z ${DISTRO} ]] && \
	echo "DISTRO=${DISTRO} not set correctly ! Exiting." && exit 1

sed -i 's/^setenv ini .*$/setenv ini L4T-'${DISTRO}'.ini/' "${scripts_dir}"/linux_boot.txt

mkimage -V && mkimage -A arm -T script -O linux -d "${scripts_dir}/linux_boot.txt" "${out}/boot.scr"
