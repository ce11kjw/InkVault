#!/system/bin/sh
# 设备伪装 + 检测对抗 统一入口
# 用法: device.sh status|reset-mac|reset-sn|hide-env|check|mods
# 设备标识本体由 ALING_MAC / ALING_Serialno 提供（外部模块，不重复实现）

MOD_DIR="/data/adb/modules/webui_info"
ALING_MAC="/data/adb/modules/ALING_MAC"
ALING_SN="/data/adb/modules/ALING_Serialno"
ALING_SE="/data/adb/modules/SELinux-LING"

json_s(){ printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e 's/	/ /g'; }

# 模块是否已装且启用
mod_state(){ # id -> installed|disabled|missing
  [ -d "/data/adb/modules/$1" ] || { printf 'missing'; return; }
  [ -f "/data/adb/modules/$1/disable" ] && { printf 'disabled'; return; }
  [ -f "/data/adb/modules/$1/remove" ] && { printf 'removing'; return; }
  printf 'enabled'
}

do_status(){
  sn=$(getprop ro.serialno)
  fp=$(getprop ro.build.fingerprint)
  model=$(getprop ro.product.model)
  brand=$(getprop ro.product.brand)
  mk=$(getprop ro.product.marketname)
  dev=$(getprop ro.product.device)
  # 主网卡 MAC（wlan0 优先）
  mac=$(cat /sys/class/net/wlan0/address 2>/dev/null)
  [ -z "$mac" ] && mac=$(cat /sys/class/net/eth0/address 2>/dev/null)
  se=$(getenforce 2>/dev/null)
  bl=$(getprop ro.boot.verifiedbootstate)
  lk=$(getprop ro.boot.flash.locked)
  vb=$(getprop ro.boot.vbmeta.device_state)
  aid=$(settings get secure android_id 2>/dev/null)
  printf '{"ok":true,"serial":"%s","mac":"%s","fingerprint":"%s","android_id":"%s",' \
    "$(json_s "$sn")" "$(json_s "$mac")" "$(json_s "$fp")" "$(json_s "$aid")"
  printf '"model":"%s","brand":"%s","marketname":"%s","device":"%s",' \
    "$(json_s "$model")" "$(json_s "$brand")" "$(json_s "$mk")" "$(json_s "$dev")"
  printf '"selinux":"%s","bootloader":"%s","flash_locked":"%s","vbmeta":"%s",' \
    "$(json_s "$se")" "$(json_s "$bl")" "$(json_s "$lk")" "$(json_s "$vb")"
  printf '"aling_mac":"%s","aling_sn":"%s","aling_selinux":"%s"}\n' \
    "$(mod_state ALING_MAC)" "$(mod_state ALING_Serialno)" "$(mod_state SELinux-LING)"
}

# 换 MAC：调 ALING_MAC 的 action 逻辑（同款生成规则 + 写回）
do_reset_mac(){
  st=$(mod_state ALING_MAC)
  [ "$st" != "enabled" ] && { printf '{"ok":false,"error":"ALING_MAC 未安装或未启用(%s)"}\n' "$st"; return 1; }
  F="$ALING_MAC/MAC/TG频道@Whitelist520"
  B="$ALING_MAC/MAC/MAC.sh"
  [ -x "$B" ] || chmod 777 "$B" 2>/dev/null
  old=$(head -1 "$F" 2>/dev/null)
  NM=$(printf '%02X:%02X:%02X:%02X:%02X:%02X' $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)))
  printf '%s\n' "$NM" > "$F" 2>/dev/null
  "$B" >/dev/null 2>&1
  sleep 1
  cur=$(cat /sys/class/net/wlan0/address 2>/dev/null)
  printf '{"ok":true,"old":"%s","generated":"%s","wlan0":"%s"}\n' "$(json_s "$old")" "$(json_s "$NM")" "$(json_s "$cur")"
}

# 换 Serialno
do_reset_sn(){
  st=$(mod_state ALING_Serialno)
  [ "$st" != "enabled" ] && { printf '{"ok":false,"error":"ALING_Serialno 未安装或未启用(%s)"}\n' "$st"; return 1; }
  F="$ALING_Serialno/Serialno/TG频道@Whitelist520"
  B="$ALING_Serialno/Serialno/Serialno.sh"
  [ -x "$B" ] || chmod 777 "$B" 2>/dev/null
  old=$(getprop ro.serialno)
  NS=$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 15)
  printf '%s\n' "$NS" > "$F" 2>/dev/null
  "$B" >/dev/null 2>&1
  sleep 1
  cur=$(getprop ro.serialno)
  printf '{"ok":true,"old":"%s","generated":"%s","now":"%s"}\n' "$(json_s "$old")" "$(json_s "$NS")" "$(json_s "$cur")"
}

# 环境隐藏（BL 属性层 + tmp 元数据）
do_hide_env(){
  sh "$MOD_DIR/scripts/envhide.sh" hide-bl 2>/dev/null
  printf '\n'
  sh "$MOD_DIR/scripts/envhide.sh" hide-tmp 2>/dev/null
}

# 检测对抗总览：读取真实状态 + 各模块装/启状态
do_check(){
  se=$(getenforce 2>/dev/null)
  bl=$(getprop ro.boot.verifiedbootstate)
  lk=$(getprop ro.boot.flash.locked)
  # root 痕迹
  root=0
  for s in /data/adb/ap /data/adb/ksu /data/adb/magisk; do [ -e "$s" ] && { root=1; break; }; done
  # su 是否可被 app 看到
  suv="unknown"
  if [ -x /system/bin/su ] || [ -x /system/xbin/su ]; then suv="visible"; else suv="hidden"; fi
  # frida
  fr=0; ls /data/local/tmp/frida* >/dev/null 2>&1 && fr=1
  ls /data/local/tmp/re.frida.server >/dev/null 2>&1 && fr=1
  # tmp 元数据
  to=$(stat -c '%U:%G' /data/local/tmp 2>/dev/null)
  tm=$(stat -c '%a' /data/local/tmp 2>/dev/null)
  ti=$(stat -c '%i' /data/local/tmp 2>/dev/null)
  # 挂载泄漏（对 app 可见的 root 挂载）
  leaks=$(grep -cE 'magisk|KSU|APatch|overlay.*adb/modules' /proc/self/mountinfo 2>/dev/null)
  # ksu_file 放行情况
  mp=""
  for p in /data/adb/ap/bin/magiskpolicy /data/adb/magisk/magiskpolicy /system/bin/magiskpolicy; do
    [ -x "$p" ] && { mp="$p"; break; }
  done
  kfile=-1
  if [ -n "$mp" ]; then
    kfile=$("$mp" --load /sys/fs/selinux/policy --print-rules 2>/dev/null | grep -cE '^allow appdomain ksu_file ')
  fi
  printf '{"ok":true,"selinux":"%s","bootloader":"%s","flash_locked":"%s","root":"%s","su":"%s","frida":%s,' \
    "$(json_s "$se")" "$(json_s "$bl")" "$(json_s "$lk")" "$([ $root -eq 1 ] && echo true || echo false)" \
    "$(json_s "$suv")" "$fr"
  printf '"tmp_owner":"%s","tmp_mode":"%s","tmp_inode":"%s","mount_leaks":%s,"ksu_file_allow":%s,' \
    "$(json_s "$to")" "$(json_s "$tm")" "$(json_s "$ti")" "${leaks:-0}" "$kfile"
  printf '"mods":['
  first=1
  for m in ALING_MAC ALING_Serialno SELinux-LING Shamiko_Service YH_YC zygisk_lsposed zygisksu hma_oss_zygisk playintegrityfix tricky_store ts_enhancer_extreme SoterFix auditpatch lib_tombstone; do
    nm=$(grep -m1 '^name=' "/data/adb/modules/$m/module.prop" 2>/dev/null | cut -d= -f2-)
    [ -z "$nm" ] && continue
    [ $first -eq 0 ] && printf ','
    first=0
    printf '{"id":"%s","name":"%s","state":"%s"}' "$(json_s $m)" "$(json_s "$nm")" "$(mod_state $m)"
  done
  printf ']}\n'
}

case "$1" in
  status)    do_status ;;
  reset-mac) do_reset_mac ;;
  reset-sn)  do_reset_sn ;;
  hide-env)  do_hide_env ;;
  check)     do_check ;;
  *) echo '{"ok":false,"error":"usage: device.sh status|reset-mac|reset-sn|hide-env|check"}' ;;
esac
exit 0
