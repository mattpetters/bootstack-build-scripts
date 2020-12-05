#!/bin/bash
if [ "$1" = 'help' ] || [ "$1" = '--help' ] || [ "$1" = '-h' ]; then
	echo "Inject u-boot.elf into coreboot.rom file"
	echo "usage: update-coreboot.sh coreboot.rom u-boot.elf"
	echo "if files not specified, the /boot/coreboot.rom and /usr/share/u-boot/u-boot.elf is used"
	exit 0
fi

COREBOOT=$(realpath ${1:-/boot/coreboot.rom})
UBOOT=$(realpath ${2:-/usr/share/u-boot/u-boot.elf})
out="$(realpath "${@:$#}")"
coreboot_branch="switch"

if ! [ -f "$COREBOOT" ]; then
	echo "$COREBOOT is not a valid file"
	exit 1
fi

if ! [ -f "$UBOOT" ]; then
        echo "$UBOOT is not a valid file"
        exit 1
fi

if [ ! -d "${out}" ]; then
	echo "${out} is not a valid directory"
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
cd util/cbfstool/
make -j${CPUS}

# Update u-boot in coreboot
echo "cbfstool \"$COREBOOT\" remove -v -n fallback/payload"
cbfstool "$COREBOOT" remove -v -n fallback/payload
echo "cbfstool \"$COREBOOT\" add-payload -v -n fallback/payload  -f \"$UBOOT\" -c lzma"
cbfstool "$COREBOOT" add-payload -v -n fallback/payload  -f "$UBOOT" -c lzma
