#!/system/bin/sh
# 环境伪装：隐藏 BL 解锁状态 + 设备安全检测
# 用法:
#   envhide.sh hide-bl     伪装 BL 为已锁定（每次开机需重跑）
#   envhide.sh check       设备安全检测(JSON)
D="$(cd "$(dirname "$0")" && pwd)"
RP=""
for p in /data/adb/magisk/resetprop /data/adb/ap/bin/resetprop /data/adb/apatch/resetprop /sbin/resetprop /system/bin/resetprop; do
  [ -x "$p" ] && RP="$p" && break
done
setprop_ro(){ "$RP" -n "$1" "$2" 2>/dev/null; }
json_s(){ printf '%s' "$1" | sed 's/\\/\\\\/g;s/"/\\"/g'; }

hide_bl(){
  if [ -z "$RP" ]; then
    printf '{"ok":false,"error":"未找到 resetprop，无法修改只读属性"}\n'
    return 1
  fi
  n=0
  for prop in \
    "ro.boot.verifiedbootstate=green" \
    "ro.boot.verifiedbootstate_lock=green" \
    "ro.boot.vbmeta.device_state=locked" \
    "ro.boot.flash.locked=1" \
    "ro.boot.veritymode=enforcing" \
    "ro.boot.enable_dm_verity=1" \
    "ro.boot.secureboot=1" \
    "ro.boot.bootlock=locked" \
    "ro.oem_unlock_supported=0" \
    "sys.oem_unlock_allowed=0" \
    "ro.boot.warranty_bit=0" \
    "ro.fmp_config=1" \
    "ro.boot.realme_lockstate=locked" \
    "ro.boot.hwc=CN" \
    "ro.boot.hwcountry=CN" ; do
    setprop_ro "${prop%=*}" "${prop#*=}"; n=$((n+1))
  done
  printf '{"ok":true,"applied":%d,"note":"BL伪装已应用，重启后需重跑"}\n' "$n"
}

check_env(){
  # 检测项：root / BL / selinux / 模拟器特征 / 危险应用
  bl_state=$(getprop ro.boot.verifiedbootstate)
  locked=$(getprop ro.boot.flash.locked)
  selinux=$(getenforce 2>/dev/null)
  root=0
  for su in /system/bin/su /system/xbin/su /data/adb/magisk /data/adb/ap /data/adb/ksu; do
    [ -e "$su" ] && { root=1; break; }
  done
  frida=0; ls /data/local/tmp/frida* >/dev/null 2>&1 && frida=1
  xposed=0; [ -e /system/framework/XposedBridge.jar ] && xposed=1
  emu=0
  getprop ro.kernel.qemu | grep -q 1 && emu=1
  # 风险应用粗查
  risky=0
  for p in com.byxiaorun.detector com.Longze.detector.pro2 com.OrangeEnvironment.Detector; do
    pm list packages 2>/dev/null | grep -q "$p" && risky=$((risky+1))
  done
  printf '{"ok":true,"bootloader":"%s","flash_locked":"%s","selinux":"%s","root":%s,"frida":%s,"xposed":%s,"emulator":%s,"risky_apps":%d}\n' \
    "$(json_s "$bl_state")" "$(json_s "$locked")" "$(json_s "$selinux")" "$root" "$frida" "$xposed" "$emu" "$risky"
}

case "$1" in
  hide-bl) hide_bl ;;
  check)   check_env ;;
  *) echo '{"ok":false,"error":"usage: envhide.sh hide-bl|check"}' ;;
esac
exit 0
