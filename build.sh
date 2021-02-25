#!/bin/bash
set -e

# Use last argument as output directory
cwd="$(realpath "$(dirname "${BASH_SOURCE[0]}")")"
out="${out:-$(realpath "${@:$#}")}"
export UBOOT=${UBOOT:-"linux-norebase"}
export ARCH=${ARCH:-"arm64"}
export CROSS_COMPILE=${CROSS_COMPILE:-"aarch64-linux-gnu-"}
export CPUS=${CPUS:-$(($(nproc) - 1))}

prepare() {
	[[ ! -d "${out}" ]] && \
		echo "${out} is not a valid directory! Exiting.." && exit 1

	[[ -z ${DISTRO} ]] && \
		echo "DISTRO=${DISTRO} not set correctly ! Exiting." && exit 1
	
	if [[ `which apt` ]]; then
		if [[ "$EUID" -ne 0 ]]; then
			echo "Please run as root"
			exit
		fi
		apt update -y && apt install -y \
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
			swig \
			python \
			python-dev \
			bc \
			curl \
			libncurses5-dev \
			m4 \
			zlib1g-dev \
			p7zip-full \
			wget \
			gnat-5
	else
		echo -e "\nNot a debian based system. Please make sure you've installed all the dependencies required for building (refer to README)"
	fi

	mkdir -p "${out}/switchroot/${DISTRO}" "${out}/bootloader/ini/"
	
	if [[ ! -d "${out}/gcc-linaro-7.5.0-2019.12-x86_64_aarch64-linux-gnu" ]]; then
		echo -e "\nSetting up aarch64 cross compiler"
		wget -q -nc --show-progress https://releases.linaro.org/components/toolchain/binaries/latest-7/aarch64-linux-gnu/gcc-linaro-7.5.0-2019.12-x86_64_aarch64-linux-gnu.tar.xz
		tar xf gcc-linaro-7.5.0-2019.12-x86_64_aarch64-linux-gnu.tar.xz -C "${out}"
		rm gcc-linaro-7.5.0-2019.12-x86_64_aarch64-linux-gnu.tar.xz
	fi

	if [[ ! -d "${out}/gcc-linaro-7.5.0-2019.12-x86_64_arm-linux-gnueabi" ]]; then
		echo -e "\nSetting up arm cross compiler"
		wget -q -nc --show-progress https://releases.linaro.org/components/toolchain/binaries/latest-7/arm-linux-gnueabi/gcc-linaro-7.5.0-2019.12-x86_64_arm-linux-gnueabi.tar.xz
		tar xf gcc-linaro-7.5.0-2019.12-x86_64_arm-linux-gnueabi.tar.xz -C "${out}"
		rm gcc-linaro-7.5.0-2019.12-x86_64_arm-linux-gnueabi.tar.xz
	fi

	PATH="$(realpath ${out}/gcc-linaro-7.5.0-2019.12-x86_64_arm-linux-gnueabi)/bin/:$(realpath ${out}/gcc-linaro-7.5.0-2019.12-x86_64_aarch64-linux-gnu)/bin/:$PATH"
}

uboot_scr() {
	echo -e "\n\t\tBuilding U-Boot scripts\n"
	cp "${cwd}/uenv_readme.txt" "${out}/switchroot/${DISTRO}"
	sed -i 's/^setenv distro.*$/setenv distro '${DISTRO}'/g' "${cwd}/linux_boot.txt"
	mkimage -V && mkimage -A arm -T script -O linux -d "${cwd}/linux_boot.txt" "${out}/switchroot/${DISTRO}/boot.scr"
}

uboot() {
	echo -e "\n\t\tBuilding U-Boot\n"
	[[ "${DISTRO}" == "android" ]] && export UBOOT="${DISTRO}"

	if [[ ! -d "${out}/switch-uboot" ]]; then
		echo -e "\n\t\tCloning switch-uboot, branch: ${UBOOT}"
		git clone -b ${UBOOT} https://gitlab.com/switchroot/bootstack/switch-uboot "${out}/switch-uboot/"
		cd "${out}/switch-uboot"
	else
		cd "${out}/switch-uboot"
		# Force uboot branch checkout if different from currently set one
		git checkout -f ${UBOOT}
	fi

	git submodule update --init --recursive .
	sed -i 's/boot_prefixes=\/ \/switchroot\/.*\/\\0/boot_prefixes=\/ \/switchroot\/'${DISTRO}'\/\\0/' "${out}/switch-uboot/include/config_distro_bootcmd.h"
	if [[ "${UBOOT}" == "android" ]]; then
		sed -i 's/boot_prefixes=\/ \/switchroot\/.*\/\\0/boot_prefixes=\/ \/switchroot\/'${DISTRO}'\/\\0/' "${out}/switch-uboot/include/configs/nintendo-switch.h"
	fi
	make nintendo-switch_defconfig
	make -j"${CPUS}"
}

coreboot() {
	echo -e "\n\t\tBuilding Coreboot\n"

	if [[ ! -d "${out}/switch-coreboot" ]]; then
		echo -e "\n\t\tCloning switch-coreboot"
		git clone https://gitlab.com/switchroot/bootstack/switch-coreboot "${out}/switch-coreboot/"
		cd "${out}/switch-coreboot/"
	else
		cd "${out}/switch-coreboot/"
		git reset --hard HEAD
		git pull
	fi
	
	git submodule update --init --recursive .

	if [[ -n "${PATCH}" ]]; then
		git apply "${cwd}/patch/coreboot_emc_oc.patch"
	fi

	make nintendo_switch_defconfig
	make iasl
	# Important won't build with more threads...
	make -j2

	mv build/coreboot.rom "${out}/switchroot/${DISTRO}"
}

uenv() {
	echo -e "\n\t\tCreate uenv.txt"
	echo -e "id=SWR-`echo ${DISTRO:0:3} | tr '[:lower:]' '[:upper:]'`
overlays=
rootdev=mmcblk0p2
runlevel=2
rootlabel_retries=1
enable_usb3=0
skip_extract=0
hdmi_fbconsole=1
usblogging=console=ttyGS0,115200,8n1
uartb=no_console_suspend console=ttyS1,115200,8n1 earlycon=tegra_comb_uart,mmio32,0x70006040
kernelcmd_run=setenv bootargs \${bootargs_extra} \"root=/dev/\${rootdev} rootfstype=ext4 rw access=m2 \\
firmware_class.path=/lib/firmware/ \\
rootlabel_retries=\${rootlabel_retries} \\
enable_usb3=\${enable_usb3} \\
skip_extract=\${skip_extract} \\
fbcon=map:\${hdmi_fbconsole} fbcon=rotate:3 \\
consoleblank=0 zswap.zpool=smalloc \\
tegra_fbmem=0x0@0x1 vpr_resize \\
nvdec_enabled=0 pmc_reboot2payload.enabled=1 \\
pmc_reboot2payload.reboot_action=bootloader \\
pmc_reboot2payload.default_payload=reboot_payload.bin \\
pmc_reboot2payload.hekate_config_id=\${id} \\
swr_dir=\${distro} \"" > "${out}/switchroot/${DISTRO}/uenv.txt"
}

misc() {
	echo -e "\nCreating ini file"
	echo -e "[L4T ${DISTRO}]
payload=switchroot/${DISTRO}/coreboot.rom
id=SWR-`echo ${DISTRO:0:3} | tr '[:lower:]' '[:upper:]'`
icon=bootloader/res/icon_${DISTRO}_hue.bmp
logopath=switchroot/${DISTRO}/bootlogo_${DISTRO}.bmp" > "${out}/bootloader/ini/L4T-${DISTRO}.ini"

	echo -e "\nAddding switchroot icons"

	mkdir -p "${out}/bootloader/res/"
	if [[ -d "${cwd}/Hekate-Icons/${DISTRO}" ]]; then
		cp "${cwd}/Hekate-Icons/${DISTRO}/icon_${DISTRO}.bmp" "${out}/switchroot/${DISTRO}/bootlogo_${DISTRO}.bmp"
		cp "${cwd}/Hekate-Icons/${DISTRO}/icon_${DISTRO}_hue.bmp" "${out}/bootloader/res/icon_${DISTRO}_hue.bmp"
	else
		cp "${cwd}/Hekate-Icons/linux/icon_linux.bmp" "${out}/switchroot/${DISTRO}/bootlogo_${DISTRO}.bmp"
		cp "${cwd}/Hekate-Icons/linux/icon_linux_hue.bmp" "${out}/bootloader/res/icon_${DISTRO}_hue.bmp"
	fi
}

compress() {
	7z a "${out}/switchroot-${DISTRO}-boot-$(date '+%Y-%m-%d').7z" "${out}/bootloader/" "${out}/switchroot/"
	rm -rf "${out}/bootloader/" "${out}/switchroot/"
}

showHelp() {
cat << EOF  
Usage: ./build [OPTIONS] <output_directory>
Build switch bootfiles

-h, --help				Display help
-c, --coreboot			Build coreboot only
-d, --distro			Set distribution name
-n, --nocomp			Build without compressing files
-p, --patch				Apply coreboot RAM overclock patch
-u, --uboot				Set uboot branch
-v, --verbose			Run script in verbose mode. Will print out each step of execution.
EOF
}

SCRIPT_OPTS='hcd:npu:v'
typeset -A ARRAY_OPTS
ARRAY_OPTS=(
	[help]=h
	[coreboot]=c
	[distro]=d
	[nocomp]=n
	[patch]=p
	[uboot]=u
	[verbose]=v
)

while getopts ${SCRIPT_OPTS} OPTION ; do
	if [[ "x$OPTION" == "x-" ]]; then
		LONG_OPTION=$OPTARG
		LONG_OPTARG=$(echo $LONG_OPTION | grep "=" | cut -d'=' -f2)
		LONG_OPTIND=-1
		[[ "x$LONG_OPTARG" = "x" ]] && LONG_OPTIND=$OPTIND || LONG_OPTION=$(echo $OPTARG | cut -d'=' -f1)
		[[ $LONG_OPTIND -ne -1 ]] && eval LONG_OPTARG="\$$LONG_OPTIND"
		OPTION=${ARRAY_OPTS[$LONG_OPTION]}
		[[ "x$OPTION" = "x" ]] &&  OPTION="?" OPTARG="-$LONG_OPTION"

		if [[ $( echo "${SCRIPT_OPTS}" | grep -c "${OPTION}:" ) -eq 1 ]]; then
		    if [[ "x${LONG_OPTARG}" = "x" ]] || [[ "${LONG_OPTARG}" = -* ]]; then 
			OPTION=":" OPTARG="-$LONG_OPTION"
		    else
			OPTARG="$LONG_OPTARG";
			if [[ $LONG_OPTIND -ne -1 ]]; then
			    [[ $OPTIND -le $Optnum ]] && OPTIND=$(( $OPTIND+1 ))
			    shift $OPTIND
			    OPTIND=1
			fi
		    fi
		fi
	fi

	if [[ "x${OPTION}" != "x:" ]] && [[ "x${OPTION}" != "x?" ]] && [[ "${OPTARG}" = -* ]]; then 
		OPTARG="$OPTION" OPTION=":"
	fi
	
	case "$OPTION" in
		h) 
			showHelp
			exit 0
			;;
		c)
			export COREBOOT=true
			;;
		d)
			export DISTRO="${OPTARG}"
			;;
		u)
			export UBOOT="${OPTARG}"
			;;
		n)
			export NO_COMPRESS=true
			;;
		p)
			export PATCH=true
			;;
		v)
			set -xv  # Set xtrace and verbose mode.
			;;
	esac
done
shift $((OPTIND-1))

prepare
uboot
coreboot
if [[ -n "${COREBOOT}" ]]; then
	mv "${out}/switchroot/${DISTRO}/coreboot.rom" "${out}"
	rm -rf "${out}/switchroot/" "${out}/bootloader/"
	echo -e "\nBuilding coreboot only finished !"
	exit 0
fi
uboot_scr
uenv
misc
if [[ -z ${NO_COMPRESS} ]]; then
	compress
fi
echo -e "\n\t\tDone building ! Output: ${out}/switchroot-${DISTRO}-boot-$(date '+%Y-%m-%d').7z"
