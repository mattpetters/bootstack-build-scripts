#!/bin/bash
out=$(realpath "${@:$#}")
overlays_dir="$(dirname "$(dirname "$(dirname "$(readlink -fm "$0")")")")"/src/uboot-scripts/overlays/

[[ ! -d "${out}" ]] && \
	echo "${out} is not a valid directory! Exiting.." && exit 1

mkdir -p "${out}/switchroot/overlays"
dtc -I dts -O dtb -o "${out}/switchroot/overlays/tegra210-icosa_emmc-overlay.dtbo" "${overlays_dir}/overlays/emmc_overlay.dts"
dtc -I dts -O dtb -o "${out}/switchroot/overlays/tegra210-icosa-UART-B-overlay.dtbo" "${overlays_dir}/overlays/uart_b_debug.dts"
