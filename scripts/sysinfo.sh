#!/system/bin/sh
ANDROID=$(getprop ro.build.version.release)
SDK=$(getprop ro.build.version.sdk)
KERNEL=$(uname -r)
DEVICE=$(getprop ro.product.model)
BRAND=$(getprop ro.product.brand)
MANUFACTURER=$(getprop ro.product.manufacturer)
BUILD_ID=$(getprop ro.build.id)
BUILD_DATE=$(getprop ro.build.date)
CPU_ABI=$(getprop ro.product.cpu.abi)
BOARD=$(getprop ro.product.board)
HARDWARE=$(getprop ro.hardware)
SECURITY=$(getprop ro.build.version.security_patch)
FINGERPRINT=$(getprop ro.build.fingerprint)
BOOTLOADER=$(getprop ro.bootloader)
SELINUX=$(getenforce 2>/dev/null || echo "Unknown")
KSU_VER=$(getprop ro.kernelsu.version 2>/dev/null)
[ -z "$KSU_VER" ] && KSU_VER=$(magisk -v 2>/dev/null || echo "Unknown")
SCREEN=$(wm size 2>/dev/null | grep -oE '[0-9]+x[0-9]+' | head -1)
DENSITY=$(wm density 2>/dev/null | grep -oE '[0-9]+' | head -1)
BATTERY=$(dumpsys battery 2>/dev/null | grep '  level' | awk '{print $2}')
UPTIME=$(awk '{printf "%d", $1}' /proc/uptime)
RAM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
RAM_MB=$(( RAM_KB / 1024 ))
TIMEZONE=$(getprop persist.sys.timezone)
LANG=$(getprop persist.sys.locale)

printf '{"android":"%s","sdk":"%s","kernel":"%s","device":"%s","brand":"%s","manufacturer":"%s","build_id":"%s","build_date":"%s","cpu_abi":"%s","board":"%s","hardware":"%s","security_patch":"%s","fingerprint":"%s","bootloader":"%s","selinux":"%s","magisk":"%s","screen":"%s","density":"%s","battery":"%s","uptime":%s,"ram_mb":%s,"timezone":"%s","lang":"%s"}' \
    "$ANDROID" "$SDK" "$KERNEL" "$DEVICE" "$BRAND" "$MANUFACTURER" \
    "$BUILD_ID" "$BUILD_DATE" "$CPU_ABI" "$BOARD" "$HARDWARE" \
    "$SECURITY" "$FINGERPRINT" "$BOOTLOADER" "$SELINUX" "$KSU_VER" \
    "$SCREEN" "$DENSITY" "${BATTERY:-0}" "${UPTIME:-0}" "${RAM_MB:-0}" \
    "$TIMEZONE" "$LANG"
