#!/usr/bin/env bash
# Setup build environment for OnePlus 12 NetHunter kernel
# Tested on Ubuntu 22.04 / 24.04 LTS

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

echo "[*] Installing build dependencies..."
sudo apt-get update -qq
sudo apt-get install -y \
    bc bison build-essential ccache curl flex \
    g++-multilib gcc-multilib git gnupg gperf \
    imagemagick lib32ncurses5-dev lib32readline-dev \
    lib32z1-dev liblz4-tool libncurses5 libncurses5-dev \
    libsdl1.2-dev libssl-dev libwxgtk3.0-gtk3-dev \
    libxml2 libxml2-utils lzop pngcrush rsync \
    schedtool squashfs-tools xsltproc zip zlib1g-dev \
    python3 python3-pip repo wget unzip cpio \
    ninja-build libelf-dev

echo "[*] Installing Android clang toolchain..."
TOOLCHAIN_DIR="$ROOT_DIR/toolchain"
mkdir -p "$TOOLCHAIN_DIR"

# Download LLVM/Clang for Android kernel (android14-6.1 or newer)
CLANG_VERSION="r487747c"
CLANG_URL="https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+archive/refs/heads/main/clang-${CLANG_VERSION}.tar.gz"

if [ ! -d "$TOOLCHAIN_DIR/clang-${CLANG_VERSION}" ]; then
    echo "[*] Downloading Clang ${CLANG_VERSION}..."
    wget -q --show-progress \
        "https://github.com/kdrag0n/proton-clang/releases/download/20210522/proton-clang-20210522.tar.zst" \
        -O "$TOOLCHAIN_DIR/clang.tar.zst" || {
        echo "[!] Primary mirror failed, trying backup..."
        # Fallback: use system clang + aarch64 cross-compiler
        sudo apt-get install -y clang lld llvm gcc-aarch64-linux-gnu
    }
fi

# Download aarch64 cross-compiler
if ! command -v aarch64-linux-gnu-gcc &>/dev/null; then
    echo "[*] Installing aarch64 cross-compiler..."
    sudo apt-get install -y gcc-aarch64-linux-gnu
fi

echo "[*] Cloning kernel source (OnePlus 12 / SM8650)..."
KERNEL_DIR="$ROOT_DIR/kernel_source"

if [ ! -d "$KERNEL_DIR" ]; then
    git clone --depth=1 \
        https://github.com/OnePlusOSS/android_kernel_oneplus_sm8650 \
        "$KERNEL_DIR" || {
        echo "[!] OnePlus source unavailable, trying AOSP GKI 6.1..."
        git clone --depth=1 --branch android14-6.1 \
            https://android.googlesource.com/kernel/common \
            "$KERNEL_DIR"
    }
fi

echo "[*] Cloning KernelSU..."
KSU_DIR="$KERNEL_DIR/KernelSU"
if [ ! -d "$KSU_DIR" ]; then
    git clone --depth=1 \
        https://github.com/tiann/KernelSU \
        "$KSU_DIR"
fi

echo "[*] Cloning AnyKernel3..."
AK3_DIR="$ROOT_DIR/AnyKernel3"
if [ ! -d "$AK3_DIR" ]; then
    git clone --depth=1 \
        https://github.com/osm0sis/AnyKernel3 \
        "$AK3_DIR"
fi

echo "[+] Setup complete!"
echo "    Kernel source : $KERNEL_DIR"
echo "    KernelSU      : $KSU_DIR"
echo "    AnyKernel3    : $AK3_DIR"
echo ""
echo "    Next: run  ./scripts/build.sh"
