#!/bin/bash
set -e

# Use last argument as output directory
out="$(realpath "${@:$#}")"
coreboot_branch="switch"
uboot_branch="linux-norebase"

[[ ! -d "${out}" ]] && \
	echo "${out} is not a valid directory! Exiting.." && exit 1

[[ -z ${DISTRO} ]] && \
	echo "DISTRO=${DISTRO} not set correctly ! Exiting." && exit 1

if [[ -n "${CPUS}" ]]; then
	if [[ ! "${CPUS}" =~ ^[0-9]{,2}$ || "${CPUS}" > $(nproc)  ]]; then
		echo "${CPUS} cores out of range or invalid, CPUS cores avalaible: $(nproc) ! Exiting..."
		exit 1
	fi
fi

mkdir -p "${out}/switchroot/overlays/" \
	"${out}/switchroot/${DISTRO}" \
	"${out}/bootloader/ini/"

cp uenv_readme.txt "${out}/switchroot/${DISTRO}"

echo -e "\n\t\tBuilding U-Boot\n"
if [[ ! -d "${out}/switch-uboot" ]]; then
	echo -e "\n\t\tCloning switch-uboot, branch: ${uboot_branch}"
	git clone -b ${uboot_branch} https://gitlab.com/switchroot/bootstack/switch-uboot "${out}/switch-uboot/"
fi

cd "${out}/switch-uboot"
git submodule update --init --recursive .
sed -i 's/boot_prefixes=\/ \/switchroot\/.*\/\\0/boot_prefixes=\/ \/switchroot\/'${DISTRO}'\/\\0/' "${out}/switch-uboot/include/config_distro_bootcmd.h"
make nintendo-switch_defconfig
make -j"${CPUS}"

echo -e "\n\t\tBuilding Coreboot\n"
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

mv build/coreboot.rom "${out}/switchroot/${DISTRO}"

echo -e "\n\t\tBuilding U-Boot scripts\n"
sed -i 's/^setenv ini .*$/setenv ini L4T-'${DISTRO}'\.ini/' linux_boot.txt
mkimage -V && mkimage -A arm -T script -O linux -d linux_boot.txt "${out}/switchroot/${DISTRO}/boot.scr"

echo -e "\n\t\tCreate hekate_ini in bootloader directory\n"
echo -e "[L4T ${DISTRO}]
payload=switchroot/${DISTRO}/coreboot.rom
id=SWR-`echo ${DISTRO:0:3} | tr '[:lower:]' '[:upper:]'`
icon=switchroot/${DISTRO}/icon_${DISTRO}_hue.bmp
logopath=switchroot/${DISTRO}/bootlogo_${DISTRO}.bmp
overlays=
rootdev=mmcblk0p2
device=mmc
root_mmc_index=0
part_num=2
runlevel=2
rootlabel_retries=1
skip_extract=0
hdmi_fbconsole=1
usblogging=console=ttyGS0,115200,8n1
uartb=no_console_suspend console=ttyS1,115200,8n1 earlycon=tegra_comb_uart,mmio32,0x70006040
kernelcmd_run=setenv bootargs \${bootargs_extra} \"root=/dev/\${rootdev} rootfstype=ext4 rw access=m2 \\
firmware_class.path=/lib/firmware/ \\
rootlabel_retries=\${rootlabel_retries} \\
skip_extract=\${skip_extract} \\
fbcon=primary:\${hdmi_fbconsole} fbcon=rotate:3 \\
consoleblank=0 zswap.zpool=smalloc \\
tegra_fbmem=0x0@0x1 vpr_resize \\
nvdec_enabled=0 pmc_reboot2payload.enabled=1 \\
pmc_reboot2payload.reboot_action=bootloader \\
pmc_reboot2payload.default_payload=reboot_payload.bin \\
pmc_reboot2payload.hekate_config_id=\${id} \"" > "${out}/bootloader/ini/L4T-${DISTRO}.ini"

echo -e "\n\t\tDone building !\n"
