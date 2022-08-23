uenv.txt configuration

=================== overlays options ====================
overlays=
 Add the overlays you want to use here.
 Separate them with space.
 These are the following:

tegra210-icosa_emmc-overlay
 Enables eMMC booting

tegra210-icosa-UART-B-overlay
 Enables UARTB logging.

usb_logging
 Enables USB logging.

auto_rootdev_disable
 Disable rootdev search done by initramfs

nfs
 Enables Network driver booting, more infos here : https://www.kernel.org/doc/Documentation/filesystems/nfs/nfsroot.txt
 Parameters are set in overlays/nfs.txt
=========================================================


================= Extra uenv parameters =================
rootdev=
 Override rootfs set in boot.scr (sdX, mmcblk0/1pX)

rootfstype=
 Type of filesystem for rootfs.

rootfs_fw=
 Set path of firmware files in rootfs.

boot_dir=
 Set path of linux bootfiles as in /${boot_dir}

rootlabel_retries=
 How many times to retry and search rootdev.
 Each iteration is 200ms. Useful when booting via USB (use 50 for 10s).

hekate_id=
 Override hekate_id set in boot.scr.

reboot_action=
 bootloader:  Reboot in bootloader menu
 via-payload: Reboot into Linux

hdmi_fbconsole=
 0: Enables console logging on built-in screen
 1: Enables console logging on DP/HDMI/VGA

orientation=
 Set fbcon rotation (default 3)
 0 - normal orientation (0 degree)
 1 - clockwise orientation (90 degrees)
 2 - upside down orientation (180 degrees)
 3 - counterclockwise orientation (270 degrees)

usblogging=
 Overlay options for usb logging.

bootargs_extra=
 Set extra kernel command line arguments.
=========================================================
