#!/system/bin/sh
# SELinux 策略硬化 —— 清除 appdomain 对 root 框架类型的大范围放行
# 背景：Duck Detector 等反作弊通过 selinux_check_access 查询
#       untrusted_app -> ksu_file:file read，若返回 Allowed 判定为 root 残留
# 原理：APatch/KernelSU 的策略生成器会写成 allow appdomain ksu_file *，
#       导致任意 app 都能访问这些类型。磁盘上实际没人用这些标签，删除零影响。
# 用法:
#   sepolicy.sh scan     检查污染情况(JSON，只读)
#   sepolicy.sh fix      修复（热加载，立即生效）
#   sepolicy.sh restore  从备份还原（需重启或再次 --live）
D="$(cd "$(dirname "$0")" && pwd)"
BD="/data/adb/fusion"
BAK="$BD/backup/policy_orig.bin"
LOG="/data/local/tmp/fusion_sepolicy.log"
logdir=$(dirname "$LOG"); [ -d "$logdir" ] || mkdir -p "$logdir" 2>/dev/null
log(){ echo "[$(date '+%F %T')] $*" >> "$LOG" 2>/dev/null; }
json_s(){ printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'; }

MP=""
for p in /data/adb/ap/bin/magiskpolicy /data/adb/magisk/magiskpolicy /system/bin/magiskpolicy; do
  [ -x "$p" ] && MP="$p" && break
done
[ -z "$MP" ] && MP=$(command -v magiskpolicy 2>/dev/null)

# 需要清理的类型（root 框架专用，普通 app 绝不该访问）
TARGET_TYPES="ksu_file magisk_file"

# 统计某类型被 appdomain 放行的规则数
count_rules() {
  "$MP" --load /sys/fs/selinux/policy --print-rules 2>/dev/null \
    | grep -cE "^allow appdomain $1 "
}

do_scan() {
  [ -z "$MP" ] && { echo '{"ok":false,"error":"未找到 magiskpolicy"}'; return 1; }
  mkdir -p "$BD" 2>/dev/null
  # 一次性导出，避免多次解析
  TMP="$BD/.policy_dump.$$"
  "$MP" --load /sys/fs/selinux/policy --print-rules 2>/dev/null > "$TMP"
  k=$(grep -cE "^allow appdomain ksu_file " "$TMP" 2>/dev/null)
  m=$(grep -cE "^allow appdomain magisk_file " "$TMP" 2>/dev/null)
  l=$(grep -cE "^allow appdomain lsposed_file " "$TMP" 2>/dev/null)
  x=$(grep -cE "^allow appdomain xposed_data " "$TMP" 2>/dev/null)
  rm -f "$TMP"
  printf '{"ok":true,"policy_tool":"%s","ksu_file":%d,"magisk_file":%d,"lsposed_file":%d,"xposed_data":%d,"dirty":%s}\n' \
    "$(json_s "$MP")" "${k:-0}" "${m:-0}" "${l:-0}" "${x:-0}" \
    "$([ "${k:-0}" -gt 0 ] || [ "${m:-0}" -gt 0 ] && echo true || echo false)"
}

do_fix() {
  [ -z "$MP" ] && { echo '{"ok":false,"error":"未找到 magiskpolicy"}'; return 1; }
  mkdir -p "$BD/backup" 2>/dev/null
  # 备份当前策略（只备份一次，保留最早的原版）
  [ -f "$BAK" ] || "$MP" --load /sys/fs/selinux/policy --save "$BAK" 2>/dev/null

  TMP="$BD/.policy_dump.$$"
  "$MP" --load /sys/fs/selinux/policy --print-rules 2>/dev/null > "$TMP"
  if [ ! -s "$TMP" ]; then rm -f "$TMP"; echo '{"ok":false,"error":"导出策略失败"}'; return 1; fi

  # 生成逐 class 的 deny 语句
  DENY="$BD/.deny_rules.$$"
  : > "$DENY"
  n=0
  for t in $TARGET_TYPES; do
    for c in $(grep "^allow appdomain $t " "$TMP" 2>/dev/null | awk '{print $4}' | sort -u); do
      echo "deny appdomain $t $c *" >> "$DENY"
      n=$((n+1))
    done
  done
  rm -f "$TMP"

  if [ "$n" -eq 0 ]; then
    rm -f "$DENY"
    printf '{"ok":true,"applied":0,"note":"无需清理（已干净）"}\n'
    return 0
  fi

  # 热加载到内核
  OUT=$("$MP" --live --apply "$DENY" 2>&1)
  rc=$?
  rm -f "$DENY"

  # 验证
  after_k=$(count_rules ksu_file)
  after_m=$(count_rules magisk_file)

  log "fix: deny=$n rc=$rc ksu=$after_k magisk=$after_m"
  if [ $rc -eq 0 ] && [ "${after_k:-1}" -eq 0 ] && [ "${after_m:-1}" -eq 0 ]; then
    printf '{"ok":true,"applied":%d,"ksu_file":0,"magisk_file":0,"note":"已立即生效，重启后需重跑"}\n' "$n"
  else
    printf '{"ok":false,"applied":%d,"ksu_file":%s,"magisk_file":%s,"error":"%s"}\n' \
      "$n" "${after_k:-?}" "${after_m:-?}" "$(json_s "$OUT")"
  fi
}

do_restore() {
  [ -z "$MP" ] && { echo '{"ok":false,"error":"未找到 magiskpolicy"}'; return 1; }
  [ -f "$BAK" ] || { echo '{"ok":false,"error":"无备份可恢复"}'; return 1; }
  "$MP" --live --load "$BAK" 2>/dev/null
  k=$(count_rules ksu_file); m=$(count_rules magisk_file)
  log "restore: ksu=$k magisk=$m"
  printf '{"ok":true,"ksu_file":%s,"magisk_file":%s,"msg":"已恢复原始策略"}\n' "${k:-?}" "${m:-?}"
}

case "$1" in
  scan)    do_scan ;;
  fix)     do_fix ;;
  restore) do_restore ;;
  *) echo '{"ok":false,"error":"usage: sepolicy.sh scan|fix|restore"}' ;;
esac
exit 0
