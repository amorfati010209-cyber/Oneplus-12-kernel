# AnyKernel3 — NetHunter Kernel for OnePlus 12 (waffle / OPD2403)
# Android 16 | Snapdragon 8 Gen 3 (SM8650)

properties() { '
kernel.string=NetHunter Kernel for OnePlus 12 by KaliNetHunter
do.devicecheck=1
do.modules=0
do.systemless=1
do.cleanup=1
do.cleanuponabort=0
device.name1=CPH2573
device.name2=OP595DL1
device.name3=CPH2573IN
device.name4=OP5959L1
device.name5=OPD2403
supported.versions=16
supported.patchlevels=
'; }

# AnyKernel methods (see /tools/ak3-core.sh)
## boot device based on product name
block=boot;
is_slot_device=1;
ramdisk_compression=auto;
patch_vbmeta_flag=auto;

. tools/ak3-core.sh

## boot shell script based method
split_boot;
flash_boot;
