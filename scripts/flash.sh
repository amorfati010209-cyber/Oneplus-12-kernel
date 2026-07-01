#!/usr/bin/env bash
# Flash NetHunter kernel to OnePlus 12 via fastboot

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="${ROOT_DIR}/dist"
OUT_DIR="${ROOT_DIR}/out"

# Find latest zip
ZIP_FILE=$(ls -t "${DIST_DIR}"/NetHunter-OnePlus12-*.zip 2>/dev/null | head -1 || true)
KERNEL_IMG="${OUT_DIR}/arch/arm64/boot/Image.lz4"

print_usage() {
    echo "Usage: $0 [--zip | --fastboot | --adb-sideload]"
    echo ""
    echo "  --fastboot      Flash kernel image directly via fastboot (boot slot)"
    echo "  --zip           Sideload flashable ZIP via adb (requires recovery)"
    echo "  --adb-sideload  Same as --zip"
    echo ""
    echo "Prerequisites:"
    echo "  - OnePlus 12 in fastboot/bootloader mode"
    echo "  - adb and fastboot installed"
    echo "  - OEM unlock enabled in Developer Options"
    echo "  - TWRP or OrangeFox recovery installed (for --zip)"
}

check_device() {
    echo "[*] Checking device connection..."
    if ! fastboot devices | grep -q "fastboot"; then
        echo "[!] No device in fastboot mode detected."
        echo "    Boot your OnePlus 12 into bootloader:"
        echo "      Power off -> hold Volume Down + Power"
        echo "    Or from adb:  adb reboot bootloader"
        exit 1
    fi
    SLOT=$(fastboot getvar current-slot 2>&1 | grep "current-slot" | awk '{print $2}')
    echo "[+] Device found. Active slot: ${SLOT:-unknown}"
}

flash_fastboot() {
    check_device
    echo "[*] Flashing kernel image via fastboot..."
    echo "    Image: $KERNEL_IMG"

    if [ ! -f "$KERNEL_IMG" ]; then
        echo "[!] Kernel image not found. Run ./scripts/build.sh first."
        exit 1
    fi

    # Determine active slot
    SLOT=$(fastboot getvar current-slot 2>&1 | grep "current-slot" | awk '{print $2}' || echo "a")
    BOOT_SLOT="boot_${SLOT}"

    echo "[*] Flashing to slot: $BOOT_SLOT"
    fastboot flash "$BOOT_SLOT" "$KERNEL_IMG"
    fastboot reboot
    echo "[+] Done! Device rebooting..."
}

sideload_zip() {
    if [ ! -f "$ZIP_FILE" ]; then
        echo "[!] No flashable ZIP found in $DIST_DIR"
        echo "    Run ./scripts/build.sh first."
        exit 1
    fi

    echo "[*] Checking adb connection (device should be in recovery)..."
    if ! adb devices | grep -q "recovery"; then
        echo "[!] No device in recovery mode."
        echo "    Boot into TWRP/OrangeFox:"
        echo "      fastboot flash recovery <recovery.img>"
        echo "      fastboot reboot recovery"
        exit 1
    fi

    echo "[*] Sideloading: $(basename "$ZIP_FILE")"
    adb sideload "$ZIP_FILE"
    echo "[+] Sideload complete. Install in TWRP and reboot."
}

case "${1:---help}" in
    --fastboot)     flash_fastboot ;;
    --zip|--adb-sideload) sideload_zip ;;
    *)              print_usage ;;
esac
