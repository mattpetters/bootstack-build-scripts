#!/bin/bash
out="$(realpath "${@:$#}")"
coreboot_branch="switch"

if [[ ! -d $out ]]; then
	echo "No directory given, exiting..."
	exit 1
fi

if [[ -n "${CPUS}" ]]; then
	if [[ ! "${CPUS}" =~ ^[0-9]{,2}$ || "${CPUS}" > $(nproc)  ]]; then
		echo "${CPUS} cores out of range or invalid, CPUS cores avalaible: $(nproc) ! Exiting..."
		exit 1
	fi
fi

if [[ ! -d "${out}/switch-coreboot" ]]; then
	echo -e "\n\t\tCloning switch-coreboot, branch: ${coreboot_branch}"
	git clone -b ${coreboot_branch} https://gitlab.com/switchroot/bootstack/switch-coreboot "${out}/switch-coreboot/"
fi

cd "${out}/switch-coreboot/"
git submodule update --init --recursive .

make crossgcc-arm CPUS=$CPUS
make crossgcc-aarch64 CPUS=$CPUS

make nintendo_switch_defconfig
make iasl

# Important won't build with more threads...
make -j2

mv build/coreboot.rom ${out}
