#!/bin/bash
set -e

# Use last argument as output directory
out="$(realpath "${@:$#}")"
_repo_dir="$(dirname "$(dirname "$(readlink -f $0)")")"
_script_dir="$(dirname "$(readlink -f $0)")"

[[ ! -d "${out}" ]] && \
	echo "${out} is not a valid directory! Exiting.." && exit 1

# Multiple variable check
[[ -z ${DISTRO} || -z ${PARTNUM} ]] && \
	echo "Variable not set correctly: DISTRO=${DISTRO} PARTNUM=${PARTNUM} ! Exiting." && exit 1

if [[ -n "${CPUS}" ]]; then
	if [[ ! "${CPUS}" =~ ^[0-9]{,2}$ || "${CPUS}" > $(nproc)  ]]; then
		echo "${CPUS} cores out of range or invalid, CPUS cores avalaible: $(nproc) ! Exiting..."
		exit 1
	fi
fi

echo -e "\n\t\tBuilding U-Boot\n"
source "${_script_dir}/uboot/build_uboot.sh" "${out}"

echo -e "\n\t\tBuilding cbfstool\n"
source "${_script_dir}/coreboot/build_cbfstool.sh" "${out}"

echo -e "\n\t\tBuilding Coreboot\n"
source "${_script_dir}/coreboot/build_coreboot.sh" "${out}"

echo -e "\n\t\tBuilding U-Boot scripts\n"
source "${_script_dir}/uboot/build_uboot_scripts.sh" "${out}"

echo -e "\n\t\tBuilding Initramfs\n"
source "${_script_dir}/initramfs/build_initramfs.sh" "${out}"

echo -e "\n\t\tBuilding Device Tree overlays\n"
source "${_script_dir}/device-tree/build_overlays.sh" "${out}"

mkdir -p "${out}/switchroot/${DISTRO}" "${out}/bootloader/ini/"

echo -e "\n\t\tCreate hekate_ini in bootloader directory\n"
{
       	echo "[L4T ${DISTRO}]"
	echo "payload=switchroot/${DISTRO}/coreboot.rom"
	echo "id=SWR-`echo ${DISTRO:0:3} | tr '[:lower:]' '[:upper:]'`"
	echo "icon=switchroot/arch/icon_${DISTRO}_hue.bmp"
	echo "logopath=switchroot/${DISTRO}/bootlogo_${DISTRO}.bmp"
} > "${out}/bootloader/ini/L4T-${DISTRO}.ini"

echo -e "\n\t\tCopying bootfiles to target directory\n"
mv "${out}/initramfs" \
	"${out}/coreboot.rom" \
	"${out}/boot.scr" \
	"${_repo_dir}/src/uboot-scripts/uenv.txt" \
	"${_repo_dir}/src/uboot-scripts/uenv_readme.txt" \
	"${out}/switchroot/${DISTRO}"

mv "${_repo_dir}/src/uboot-scripts/overlays/" "${out}/switchroot/"

echo -e "\n\t\tDone building !\n"
