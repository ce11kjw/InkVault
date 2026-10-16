#!/system/bin/sh
# 设备指纹伪装 / 恢复（融合 Fish 的希腊字母混淆法）
# 用法:
#   fp.sh status                查看当前指纹与备份状态(JSON)
#   fp.sh spoof [n]             随机把 n 个拉丁字母换成希腊同形字(默认 n=4)
#   fp.sh spoof-full <值>       直接设置完整 fingerprint
#   fp.sh restore               恢复出厂原始指纹
#   fp.sh ids                   查看/重置 设备标识(serialno/meid 等)
#   fp.sh random-ids            随机化 serialno / meid
D="$(cd "$(dirname "$0")" && pwd)"
BAK="/data/adb/fusion/fp_backup.prop"
mkdir -p /data/adb/fusion

RP=""
for p in /data/adb/magisk/resetprop /data/adb/ap/bin/resetprop /data/adb/apatch/resetprop /sbin/resetprop /system/bin/resetprop /system_ext/bin/resetprop /product/bin/resetprop; do
  [ -x "$p" ] && RP="$p" && break
done
[ -z "$RP" ] && command -v resetprop >/dev/null 2>&1 && RP="resetprop"

setprop_ro(){ # key value
  if [ -n "$RP" ]; then "$RP" "$1" "$2" 2>/dev/null; else setprop "$1" "$2" 2>/dev/null; fi
}

# 拉丁→希腊同形字映射
to_greek(){
  case "$1" in
    a) printf 'α';; b) printf 'β';; c) printf 'κ';; d) printf 'δ';; e) printf 'ε';;
    f) printf 'φ';; g) printf 'γ';; h) printf 'η';; i) printf 'ι';; j) printf 'ι';;
    k) printf 'κ';; l) printf 'λ';; m) printf 'μ';; n) printf 'ν';; o) printf 'ο';;
    p) printf 'π';; q) printf 'κ';; r) printf 'ρ';; s) printf 'σ';; t) printf 'τ';;
    u) printf 'υ';; v) printf 'υ';; w) printf 'ω';; x) printf 'χ';; y) printf 'υ';; z) printf 'ζ';;
    *) printf '%s' "$1";;
  esac
}

json_s(){ printf '%s' "$1" | sed 's/\\/\\\\/g;s/"/\\"/g'; }

case "$1" in
  status)
    cur=$(getprop ro.build.fingerprint)
    [ -f "$BAK" ] && hasbak=true || hasbak=false
    printf '{"ok":true,"fingerprint":"%s","has_backup":%s,"resetprop":"%s","serial":"%s"}\n' \
      "$(json_s "$cur")" "$hasbak" "$(json_s "$RP")" "$(json_s "$(getprop ro.serialno)")"
    ;;
  spoof)
    n="${2:-4}"
    cur=$(getprop ro.build.fingerprint)
    [ -f "$BAK" ] || printf '%s\n' "$cur" > "$BAK"
    # 逐字符替换 n 个小写拉丁字母
    out=""; i=0; len=${#cur}; cnt=0
    while [ $i -lt $len ]; do
      ch=$(printf '%s' "$cur" | cut -c$((i+1)))
      if [ $cnt -lt "$n" ] && printf '%s' "$ch" | grep -q '^[a-z]$'; then
        out="$out$(to_greek "$ch")"; cnt=$((cnt+1))
      else
        out="$out$ch"
      fi
      i=$((i+1))
    done
    setprop_ro ro.build.fingerprint "$out"
    sleep 1
    now=$(getprop ro.build.fingerprint)
    printf '{"ok":true,"old":"%s","new":"%s","applied":%s}\n' \
      "$(json_s "$cur")" "$(json_s "$now")" "$([ "$now" = "$out" ] && echo true || echo false)"
    ;;
  spoof-full)
    [ -f "$BAK" ] || getprop ro.build.fingerprint > "$BAK"
    setprop_ro ro.build.fingerprint "$2"
    printf '{"ok":true,"new":"%s"}\n' "$(json_s "$2")"
    ;;
  restore)
    if [ -f "$BAK" ]; then
      orig=$(cat "$BAK")
      setprop_ro ro.build.fingerprint "$orig"
      printf '{"ok":true,"restored":"%s"}\n' "$(json_s "$orig")"
    else
      printf '{"ok":false,"error":"无备份可恢复"}\n'
    fi
    ;;
  ids)
    printf '{"serial":"%s","meid":"%s","android_id":"%s"}\n' \
      "$(json_s "$(getprop ro.serialno)")" \
      "$(json_s "$(getprop ro.ril.oem.meid)")" \
      "$(json_s "$(settings get secure android_id 2>/dev/null)")"
    ;;
  random-ids)
    new_serial=$(date +%s%N | md5sum | cut -c1-10)
    new_meid="9900$(od -An -N4 -tu4 /dev/urandom | tr -d ' ')"
    [ -f "$BAK" ] || { echo "ro.serialno=$(getprop ro.serialno)" >> "$BAK"; echo "ro.ril.oem.meid=$(getprop ro.ril.oem.meid)" >> "$BAK"; }
    setprop_ro ro.serialno "$new_serial"
    setprop_ro ro.ril.oem.meid "$new_meid"
    printf '{"ok":true,"serial":"%s","meid":"%s"}\n' "$new_serial" "$new_meid"
    ;;
  *)
    echo '{"ok":false,"error":"usage: fp.sh status|spoof [n]|spoof-full <v>|restore|ids|random-ids"}'
    ;;
esac
exit 0
