#!/usr/bin/env bash
# Build NetHunter kernel for OnePlus 12 (SM8650 / Android 16)
# Usage: ./scripts/build.sh [--ksu] [--clean] [--jobs N]

set -euo pipefail

# ─── Paths ────────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
KERNEL_DIR="${ROOT_DIR}/kernel_source"
OUT_DIR="${ROOT_DIR}/out"
DIST_DIR="${ROOT_DIR}/dist"
AK3_DIR="${ROOT_DIR}/AnyKernel3"
NH_CONFIG_DIR="${ROOT_DIR}/nethunter-config"
PATCHES_DIR="${ROOT_DIR}/patches"

# ─── Toolchain ────────────────────────────────────────────────────────────────
CLANG_DIR="${ROOT_DIR}/toolchain/clang"
if [ -d "$CLANG_DIR/bin" ]; then
    export PATH="$CLANG_DIR/bin:$PATH"
fi

# ─── Device / Build config ────────────────────────────────────────────────────
ARCH="arm64"
SUBARCH="arm64"
CROSS_COMPILE="aarch64-linux-gnu-"
CROSS_COMPILE_COMPAT="arm-linux-gnueabi-"
CC="clang"
DEFCONFIG="vendor/pineapple_GKI.config"   # OnePlus 12 (SM8650 platform = pineapple)
KERNEL_VERSION="nethunter-$(date +%Y%m%d)"
JOBS=$(nproc)

# ─── Parse args ───────────────────────────────────────────────────────────────
WITH_KSU=true
CLEAN=false

for arg in "$@"; do
    case $arg in
        --no-ksu)    WITH_KSU=false ;;
        --clean)     CLEAN=true ;;
        --jobs)      shift; JOBS="$1" ;;
        -j*)         JOBS="${arg#-j}" ;;
    esac
done

# ─── Sanity checks ────────────────────────────────────────────────────────────
if [ ! -d "$KERNEL_DIR" ]; then
    echo "[!] Kernel source not found: $KERNEL_DIR"
    echo "    Run ./scripts/setup.sh first"
    exit 1
fi

mkdir -p "$OUT_DIR" "$DIST_DIR"

# ─── KernelSU integration ─────────────────────────────────────────────────────
if $WITH_KSU; then
    echo "[*] Integrating KernelSU..."
    KSU_DIR="${KERNEL_DIR}/KernelSU"

    if [ ! -d "$KSU_DIR" ]; then
        git clone --depth=1 \
            https://github.com/tiann/KernelSU \
            "$KSU_DIR"
    else
        git -C "$KSU_DIR" pull --rebase --autostash
    fi

    # Patch drivers/Makefile to include KernelSU
    if ! grep -q "KernelSU" "${KERNEL_DIR}/drivers/Makefile"; then
        echo "obj-\$(CONFIG_KSU) += ../KernelSU/kernel/" \
            >> "${KERNEL_DIR}/drivers/Makefile"
        echo "obj-\$(CONFIG_KSU) += ../KernelSU/kernel/" \
            >> "${KERNEL_DIR}/drivers/Kconfig" 2>/dev/null || true
    fi

    # Add KernelSU Kconfig source
    if ! grep -q "KernelSU" "${KERNEL_DIR}/drivers/Kconfig"; then
        printf '\nsource "KernelSU/kernel/Kconfig"\n' \
            >> "${KERNEL_DIR}/drivers/Kconfig"
    fi
fi

# ─── Apply NetHunter patches ──────────────────────────────────────────────────
echo "[*] Applying NetHunter patches..."
cd "$KERNEL_DIR"
for patch in "${PATCHES_DIR}"/*.patch; do
    echo "    -> $(basename "$patch")"
    git apply --ignore-whitespace "$patch" 2>/dev/null || \
        patch -p1 --forward --ignore-whitespace < "$patch" 2>/dev/null || \
        echo "    [!] Already applied or skipped: $(basename "$patch")"
done
cd -

# ─── Clean ────────────────────────────────────────────────────────────────────
if $CLEAN; then
    echo "[*] Cleaning output directory..."
    rm -rf "$OUT_DIR"
    mkdir -p "$OUT_DIR"
fi

# ─── Generate defconfig ───────────────────────────────────────────────────────
echo "[*] Generating defconfig: $DEFCONFIG"
make -C "$KERNEL_DIR" \
    O="$OUT_DIR" \
    ARCH=$ARCH \
    SUBARCH=$SUBARCH \
    CC=$CC \
    CROSS_COMPILE=$CROSS_COMPILE \
    CROSS_COMPILE_COMPAT=$CROSS_COMPILE_COMPAT \
    LLVM=1 \
    LLVM_IAS=1 \
    "$DEFCONFIG"

# ─── Merge NetHunter config fragments ─────────────────────────────────────────
echo "[*] Merging NetHunter config fragments..."
./kernel_source/scripts/kconfig/merge_config.sh -m -O "$OUT_DIR" \
    "${OUT_DIR}/.config" \
    "${NH_CONFIG_DIR}/nethunter.config" \
    "${NH_CONFIG_DIR}/nethunter-wifi.config"

# Regenerate merged config
make -C "$KERNEL_DIR" \
    O="$OUT_DIR" \
    ARCH=$ARCH \
    CC=$CC \
    CROSS_COMPILE=$CROSS_COMPILE \
    LLVM=1 \
    LLVM_IAS=1 \
    olddefconfig

# ─── Build kernel ─────────────────────────────────────────────────────────────
echo "[*] Building kernel with $JOBS jobs..."
BUILD_START=$(date +%s)

make -C "$KERNEL_DIR" \
    O="$OUT_DIR" \
    ARCH=$ARCH \
    SUBARCH=$SUBARCH \
    CC=$CC \
    CROSS_COMPILE=$CROSS_COMPILE \
    CROSS_COMPILE_COMPAT=$CROSS_COMPILE_COMPAT \
    LLVM=1 \
    LLVM_IAS=1 \
    -j"$JOBS" \
    Image.lz4 dtbs

BUILD_END=$(date +%s)
ELAPSED=$(( BUILD_END - BUILD_START ))
echo "[+] Build finished in ${ELAPSED}s"

# ─── Build DTB ────────────────────────────────────────────────────────────────
echo "[*] Building DTB overlay..."
make -C "$KERNEL_DIR" \
    O="$OUT_DIR" \
    ARCH=$ARCH \
    CC=$CC \
    CROSS_COMPILE=$CROSS_COMPILE \
    LLVM=1 \
    LLVM_IAS=1 \
    -j"$JOBS" \
    dtbo.img 2>/dev/null || echo "    [!] dtbo.img skipped (may not be needed)"

# ─── Package with AnyKernel3 ─────────────────────────────────────────────────
echo "[*] Packaging flashable zip with AnyKernel3..."

if [ ! -d "$AK3_DIR" ]; then
    git clone --depth=1 \
        https://github.com/osm0sis/AnyKernel3 \
        "$AK3_DIR"
fi

# Copy kernel image
cp "${OUT_DIR}/arch/arm64/boot/Image.lz4" "${AK3_DIR}/"

# Copy DTBs if present
DTB_DIR="${OUT_DIR}/arch/arm64/boot/dts"
if [ -d "$DTB_DIR" ]; then
    find "$DTB_DIR" -name "*.dtb" -exec cp {} "${AK3_DIR}/dtbs/" \; 2>/dev/null || true
fi

# Copy DTBO if present
[ -f "${OUT_DIR}/arch/arm64/boot/dtbo.img" ] && \
    cp "${OUT_DIR}/arch/arm64/boot/dtbo.img" "${AK3_DIR}/"

# Write AnyKernel3 config
cat > "${AK3_DIR}/anykernel.sh" << 'AKEOF'
# AnyKernel3 config for OnePlus 12 (waffle) — NetHunter kernel
properties() { '
kernel.string=NetHunter Kernel for OnePlus 12
do.devicecheck=1
do.modules=0
do.systemless=1
do.cleanup=1
do.cleanuponabort=0
device.name1=OP5959L1
device.name2=OPD2403
device.name3=waffle
device.name4=OP5959EEA
supported.versions=16
supported.patchlevels=
'; }

block=boot;
is_slot_device=1;
ramdisk_compression=auto;

. tools/ak3-core.sh
. tools/flash.sh
AKEOF

# Zip up
ZIP_NAME="NetHunter-OnePlus12-Android16-${KERNEL_VERSION}.zip"
cd "$AK3_DIR"
zip -r9 "${DIST_DIR}/${ZIP_NAME}" . -x "*.git*" -x "*.DS_Store"
cd -

echo ""
echo "========================================="
echo " [+] DONE!"
echo "========================================="
echo " Flashable ZIP : ${DIST_DIR}/${ZIP_NAME}"
echo " Kernel image  : ${OUT_DIR}/arch/arm64/boot/Image.lz4"
echo ""
echo " Flash via TWRP / OrangeFox recovery:"
echo "   adb sideload ${DIST_DIR}/${ZIP_NAME}"
echo "=========================================
"
