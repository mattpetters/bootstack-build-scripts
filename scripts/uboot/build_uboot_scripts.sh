#!/bin/bash
out=$(realpath "${@:$#}")
scripts_dir="$(dirname "$(dirname "$(dirname "${BASH_SOURCE[0]}")")")"/src/uboot-scripts

[[ ! -d "${out}" ]] && \
	echo "${out} is not a valid directory! Exiting.." && exit 1

[[ -z ${DISTRO} || -z ${PARTNUM} ]] && \
	echo "Variable not set correctly: DISTRO=${DISTRO} PARTNUM=${PARTNUM} ! Exiting." && exit 1

sed -i 's/^setenv hkt_idx .*$/setenv hekate_id SWR-'$(echo ${DISTRO:0:3} | tr '[:lower:]' '[:upper:]')'/' "${scripts_dir}"/linux_boot.txt
sed -i 's/^setenv part_idx .*$/setenv rootdev '${PARTNUM}'/' "${scripts_dir}"/linux_boot.txt
sed -i 's/^setenv linux_dir .*$/setenv linux_dir '${DISTRO}'/' "${scripts_dir}"/linux_boot.txt

sed -i 's/^hekate_id=.*$/hekate_id=SWR-'`echo ${DISTRO:0:3} | tr '[:lower:]' '[:upper:]'`'/' "${scripts_dir}"/uenv.txt
sed -i 's/^rootdev=.*$/rootdev='${PARTNUM}'/' "${scripts_dir}"/uenv.txt

mkimage -V && mkimage -A arm -T script -O linux -d "${scripts_dir}/linux_boot.txt" "${out}/boot.scr"
