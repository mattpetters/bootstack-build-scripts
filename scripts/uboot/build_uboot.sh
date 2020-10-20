#!/bin/bash
out="$(realpath "${@:$#}")"
uboot_branch="linux-norebase"

[[ -z ${DISTRO} ]] && \
	echo "Nothing set for DISTRO variable..Exiting." && exit 1

[[ ! -d "${out}" ]] && \
	echo "${out} is not a valid directory! Exiting.." && exit 1


if [[ -n "${CPUS}" ]]; then
	if [[ ! "${CPUS}" =~ ^[0-9]{,2}$ || "${CPUS}" > $(nproc)  ]]; then
		echo "${CPUS} cores out of range or invalid, CPUS cores avalaible: $(nproc) ! Exiting..."
		exit 1
	fi
fi

if [[ ! -d "${out}/switch-uboot" ]]; then
	echo -e "\n\t\tCloning switch-uboot, branch: ${uboot_branch}"
	git clone -b ${uboot_branch} https://gitlab.com/switchroot/bootstack/switch-uboot "${out}/switch-uboot/"
fi

cd "${out}/switch-uboot"
git submodule update --init --recursive .
sed -i 's/boot_prefixes=\/ \/switchroot\/.*\/\\0/boot_prefixes=\/ \/switchroot\/'${DISTRO}'\/\\0/' "${out}/switch-uboot/include/config_distro_bootcmd.h"
make nintendo-switch_defconfig
make -j"${CPUS}"
