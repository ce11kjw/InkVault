#!/system/bin/sh
# 模块快捷操作（APatch/KernelSU 管理器里点击模块按钮触发）

MODDIR="${0%/*}"
[ -z "$MODDIR" ] && MODDIR="/data/adb/modules/webui_info"

echo "╭──────────────────────╮"
echo "│   墨匣 InkVault      │"
echo "╰──────────────────────╯"
echo ""

# 版本
if [ -f "$MODDIR/module.prop" ]; then
  V=$(grep '^version=' "$MODDIR/module.prop" | cut -d= -f2)
  VC=$(grep '^versionCode=' "$MODDIR/module.prop" | cut -d= -f2)
  echo "版本: $V (code $VC)"
fi
echo ""

# 设备标识
echo "【设备标识】"
echo "  Serialno : $(getprop ro.serialno)"
echo "  wlan0 MAC: $(cat /sys/class/net/wlan0/address 2>/dev/null)"
echo "  AndroidID: $(settings get secure android_id 2>/dev/null)"
echo ""

# 环境
echo "【环境】"
echo "  SELinux  : $(getenforce 2>/dev/null)"
echo "  BL 状态  : $(getprop ro.boot.verifiedbootstate) / locked=$(getprop ro.boot.flash.locked)"
echo ""

# 关键检测项
echo "【检测项】"
K=0
for s in /system/bin/su /system/xbin/su; do
  [ -e "$s" ] && K=1
done
echo "  su 可见  : $([ $K -eq 1 ] && echo '⚠ 可见' || echo '已隐藏')"
F=0; ls /data/local/tmp/frida* >/dev/null 2>&1 && F=1
echo "  Frida    : $([ $F -eq 1 ] && echo '⚠ 有残留' || echo '无')"
MP=""
for p in /data/adb/ap/bin/magiskpolicy /data/adb/magisk/magiskpolicy /system/bin/magiskpolicy; do
  [ -x "$p" ] && MP="$p" && break
done
if [ -n "$MP" ]; then
  N=$("$MP" --load /sys/fs/selinux/policy --print-rules 2>/dev/null | grep -c '^allow appdomain ksu_file ')
  echo "  ksu_file : $N 条放行 $([ "$N" -gt 0 ] && echo '⚠ 需硬化' || echo '✅')"
fi
echo ""

# 开机日志尾部
echo "【最近开机日志】"
if [ -f /data/local/tmp/webui_service.log ]; then
  tail -5 /data/local/tmp/webui_service.log
else
  echo "  （无日志）"
fi
echo ""
echo "━━━━━━━━━━━━━━━━━━━━"
echo "打开 WebUI 查看完整面板"
echo "快捷命令: sh $MODDIR/scripts/device.sh status"
