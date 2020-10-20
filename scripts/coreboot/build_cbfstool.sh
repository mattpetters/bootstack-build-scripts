#!/bin/bash
_cwd=$(pwd)
out="$(realpath "${@:$#}")"
coreboot_branch="switch-proper-vpr"

[[ ! -d "${out}" ]] && \
	echo "${out} is not a valid directory! Exiting.." && exit 1

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
cd util/cbfstool/
make -j${CPUS}

cp cbfstool "$(dirname "${BASH_SOURCE[0]}")"
