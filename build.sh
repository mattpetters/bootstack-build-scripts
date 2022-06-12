#!/bin/bash
set -e

# Use last argument as output directory
cwd="$(realpath "$(dirname "${BASH_SOURCE[0]}")")"
out="${out:-$(realpath "${@:$#}")}"
export UBOOT=${UBOOT:-"linux-norebase"}
export ARCH=${ARCH:-"arm64"}
export CROSS_COMPILE=${CROSS_COMPILE:-"aarch64-linux-gnu-"}
export CPUS=${CPUS:-$(($(nproc) - 1))}
export SLD0=${SLD0:-"BUILD_VER_SUFFIX=SLD0"}

prepare() {
	[[ ! -d "${out}" ]] && \
		echo -e "\n${out} is not a valid directory! Exiting.." && exit 1

	[[ -z ${DISTRO} ]] && \
		echo -e "\nDISTRO=${DISTRO} not set correctly ! Exiting." && exit 1
	
	if [[ $(which apt) ]]; then
	
		if [[ "$EUID" -ne 0 ]]; then
			echo -e "\nPlease run as root"
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
            acpica-tools || true
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

	[[ "${DISTRO}" == "android" ]] && export UBOOT="${DISTRO}"

	if [[ ! -d "${out}/switch-uboot" ]]; then
		echo -e "\ntCloning switch-uboot, branch: ${UBOOT}"
		git clone -b ${UBOOT} https://gitlab.com/switchroot/bootstack/switch-uboot "${out}/switch-uboot/"
		cd "${out}/switch-uboot"
	else
		cd "${out}/switch-uboot"
		# Force uboot branch checkout if different from currently set one
		git checkout -f ${UBOOT}
	fi
	git submodule update --init --recursive .

	if [[ ! -d "${out}/switch-coreboot" ]]; then
		echo -e "\nCloning switch-coreboot"
		git clone -b switch-linux https://gitlab.com/switchroot/bootstack/switch-coreboot "${out}/switch-coreboot/"
		cd "${out}/switch-coreboot/"
	else
		cd "${out}/switch-coreboot/"
		git reset --hard HEAD
		git pull
	fi
	
	git submodule update --init --recursive .

	if [[ -n "${PATCH}" ]]; then
		git apply "${cwd}/assets/patch/coreboot_emc_oc.patch"
	fi
}

cbfstool() {	
	cd "${out}/switch-coreboot/util/cbfstool/"
	make -j${CPUS}
}

uboot() {
	echo -e "\nBuilding U-Boot"
	cd "${out}/switch-uboot"
	sed -i 's/boot_prefixes=\/ \/switchroot\/.*\/\\0/boot_prefixes=\/ \/switchroot\/'${DISTRO}'\/\\0/' "${out}/switch-uboot/include/config_distro_bootcmd.h"
	if [[ "${UBOOT}" == "android" ]]; then
		sed -i 's/boot_prefixes=\/ \/switchroot\/.*\/\\0/boot_prefixes=\/ \/switchroot\/'${DISTRO}'\/\\0/' "${out}/switch-uboot/include/configs/nintendo-switch.h"
	fi

	# Apply uboot patch on non ubuntu bionic distro
	source /etc/os-release
	if [[ $(echo $VERSION | cut -d" " -f 1) != "18.04" ]]; then
		git apply "${cwd}/assets/patch/uboot.diff"
	fi

	make nintendo-switch_defconfig
	make -j"${CPUS}"
}

coreboot() {
	echo -e "\nBuilding Coreboot"
	cd "${out}/switch-coreboot/"
	make nintendo_switch_defconfig
	# Important won't build with more threads...
	make -j2 ${SDL0}

	mv build/coreboot.rom "${out}/switchroot/${DISTRO}"
}

misc() {
	new_id=SWR-$(echo ${DISTRO:0:3} | tr '[:lower:]' '[:upper:]')

	echo -e "\nBuilding U-Boot scripts"
	cp "${cwd}/assets/uenv_readme.txt" "${out}/switchroot/${DISTRO}"

	cp "${cwd}/assets/boot.txt" "${out}"
	sed -i 's/setenv hekate_id.*$/setenv hekate_id '$new_id'/g' "${out}/boot.txt"
	mkimage -V && mkimage -A arm -T script -O linux -d "${out}/boot.txt" "${out}/switchroot/${DISTRO}/boot.scr"
	rm "${out}/boot.txt"

	echo -e "\nCreating uenv.txt"
	cp "${cwd}/assets/uenv.txt" "${out}/switchroot/${DISTRO}"
	sed -i 's/hekate_id=.*$/hekate_id='$new_id'/g' "${out}/switchroot/${DISTRO}/uenv.txt"

	echo -e "\nCreating ini file"
	echo -e "[L4T ${DISTRO}]
payload=switchroot/${DISTRO}/coreboot.rom
id=$new_id
icon=bootloader/res/icon_${DISTRO}_hue.bmp
logopath=switchroot/${DISTRO}/bootlogo_${DISTRO}.bmp" > "${out}/bootloader/ini/L4T-${DISTRO}.ini"

	echo -e "\nAddding switchroot icons"
	mkdir -p "${out}/bootloader/res/"
	if [[ -d "${cwd}/assets/Hekate-Icons/${DISTRO}" ]]; then
		cp "${cwd}/assets/Hekate-Icons/${DISTRO}/icon_${DISTRO}.bmp" "${out}/switchroot/${DISTRO}/bootlogo_${DISTRO}.bmp"
		cp "${cwd}/assets/Hekate-Icons/${DISTRO}/icon_${DISTRO}_hue.bmp" "${out}/bootloader/res/icon_${DISTRO}_hue.bmp"
	else
		cp "${cwd}/assets/Hekate-Icons/linux/icon_linux.bmp" "${out}/switchroot/${DISTRO}/bootlogo_${DISTRO}.bmp"
		cp "${cwd}/assets/Hekate-Icons/linux/icon_linux_hue.bmp" "${out}/bootloader/res/icon_${DISTRO}_hue.bmp"
	fi
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
-s, --sld				Build without SLD0 support
-v, --verbose			Run script in verbose mode. Will print out each step of execution.
EOF
}

SCRIPT_OPTS='hcd:npu:sv'
typeset -A ARRAY_OPTS
ARRAY_OPTS=(
	[help]=h
	[coreboot]=c
	[distro]=d
	[nocomp]=n
	[patch]=p
	[uboot]=u
	[sld]=s
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
		s)
			export SLD0=""
			;;
		v)
			set -xv  # Set xtrace and verbose mode.
			;;
	esac
done
shift $((OPTIND-1))

prepare
cbfstool
uboot
coreboot
if [[ -n "${COREBOOT}" ]]; then
	mv "${out}/switchroot/${DISTRO}/coreboot.rom" "${out}"
	rm -rf "${out}/switchroot/" "${out}/bootloader/"
	echo -e "\nDone building coreboot!"
	exit 0
fi

misc

if [[ -z ${NO_COMPRESS} ]]; then
	7z a "${out}/switchroot-${DISTRO}-boot.7z" "${out}/bootloader/" "${out}/switchroot/"
	rm -rf "${out}/bootloader/" "${out}/switchroot/"
	echo -e "\nDone building! Output: ${out}/switchroot-${DISTRO}-boot.7z"
fi
