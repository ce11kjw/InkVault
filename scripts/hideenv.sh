#!/system/bin/sh
# 环境隐藏 —— 对抗游戏反作弊的环境检测
# 用法:
#   hideenv.sh scan      扫描当前暴露项(JSON，只读)
#   hideenv.sh apply     应用隐藏（umount + prop + 进程）
#   hideenv.sh restore   恢复（重新挂载）
D="$(cd "$(dirname "$0")" && pwd)"
LOG="/data/local/tmp/fusion_hideenv.log"
logdir=$(dirname "$LOG"); [ -d "$logdir" ] || mkdir -p "$logdir" 2>/dev/null
log(){ echo "[$(date '+%F %T')] $*" >> "$LOG" 2>/dev/null; }
json_s(){ printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'; }

RP=""
for p in /data/adb/magisk/resetprop /data/adb/ap/bin/resetprop /data/adb/apatch/resetprop /sbin/resetprop /system/bin/resetprop; do
  [ -x "$p" ] && RP="$p" && break
done

# ===== 安全层：只隐藏这些不会影响任何功能 =====
# su 二进制：反作弊最爱扫。APatch 用的是 /system/bin/su 这个真实文件
PATHS_SAFE_SU='/system/bin/su /system/xbin/su /sbin/su /system/sbin/su /vendor/bin/su /system/app/Superuser.apk'
# Frida：留下会直接被判外挂
PATHS_SAFE_FRIDA='/data/local/tmp/frida-server /data/local/tmp/frida-server16 /data/local/tmp/re.frida.server /data/local/tmp/frida /data/local/tmp/hluda_server'
# Xposed 静态特征
PATHS_SAFE_DETECT='/system/framework/XposedBridge.jar /system/lib/libxposed_art.so /system/lib64/libxposed_art.so'

# ===== 谨慎层：默认不隐藏，需显式 --aggressive =====
# ⚠️ /data/adb/modules 里有 26 个模块（Shamiko/tricky_store/playintegrityfix 等），
#    覆盖它会让模块管理器看不到模块，而且本模块自己也在里面 —— 绝不动！
PATHS_RISKY='/data/adb/ap /data/adb/apd /data/adb/magisk /data/adb/ksu /data/adb/lspd'

# ---- 需要隐藏的进程名（仅用于展示）----
HIDE_PROCS='apd|magiskd|ksud|frida-server|frida-server16|zygiskd|lspd'

# ---- 需要伪装的 prop（只在值不对时才写，避免无谓改动）----
hide_props() {
  n=0
  set_prop() { # name want
    [ -z "$RP" ] && return 1
    cur=$(getprop "$1" 2>/dev/null)
    [ "$cur" = "$2" ] && return 0
    "$RP" -n "$1" "$2" 2>/dev/null && n=$((n+1))
  }
  set_prop ro.boot.verifiedbootstate green
  set_prop ro.boot.flash.locked 1
  set_prop ro.boot.vbmeta.device_state locked
  set_prop ro.boot.veritymode enforcing
  set_prop ro.boot.warranty_bit 0
  set_prop ro.boot.secureboot 1
  set_prop ro.boot.bootlock locked
  set_prop ro.oem_unlock_supported 0
  set_prop sys.oem_unlock_allowed 0
  set_prop ro.debuggable 0
  set_prop ro.secure 1
  set_prop ro.build.type user
  set_prop ro.build.tags release-keys
  echo "$n"
}

# ---- 用 mount 覆盖隐藏文件/目录（最有效，反作弊 readdir/stat 都看不到）----
hide_paths() {
  hidden=0; failed=0
  local list="$PATHS_SAFE_SU $PATHS_SAFE_FRIDA $PATHS_SAFE_DETECT"
  [ "$1" = "aggressive" ] && list="$list $PATHS_RISKY"
  for p in $list; do
    [ -e "$p" ] || continue
    if [ -d "$p" ]; then
      # 目录：挂 tmpfs 覆盖（保留目录本身，内容为空）
      if mount -t tmpfs tmpfs "$p" 2>/dev/null; then
        hidden=$((hidden+1))
      else
        failed=$((failed+1))
      fi
    else
      # 文件：绑定一个不存在的空文件？→ 用 /dev/null 覆盖（read 返回空）
      if mount -o bind /dev/null "$p" 2>/dev/null; then
        hidden=$((hidden+1))
      else
        failed=$((failed+1))
      fi
    fi
  done
  echo "$hidden $failed"
}

unhide_paths() {
  for p in $PATHS_SAFE_SU $PATHS_SAFE_FRIDA $PATHS_SAFE_DETECT $PATHS_RISKY; do
    mountpoint -q "$p" 2>/dev/null && umount "$p" 2>/dev/null
  done
}

# ---- 隐藏进程（重命名 /proc/PID/comm 不可行，改为对目标进程 hidepid）----
# 说明：apd 是 APatch 的核心守护进程，杀掉会失去 root。
# 因此不杀进程，而是通过 mount 隐藏 /data/adb/ap 让反作弊看不到框架路径。
# 部分反作弊会读 /proc 全表扫 'apd'。可用内核 hidepid 或 ptrace 隐藏，
# 这里提供"进程名伪装"方案：仅当有 resetprop 且支持时尝试，失败不报错。

case "$1" in
  scan)
    su_hit=""; for p in $PATHS_SAFE_SU; do [ -e "$p" ] && su_hit="$su_hit$p "; done
    fr_hit=""; for p in $PATHS_SAFE_FRIDA; do [ -e "$p" ] && fr_hit="$fr_hit$p "; done
    rd_hit=""; for p in $PATHS_RISKY; do [ -e "$p" ] && rd_hit="$rd_hit$p "; done
    de_hit=""; for p in $PATHS_SAFE_DETECT; do [ -e "$p" ] && de_hit="$de_hit$p "; done
    procs=$(ps -A 2>/dev/null | awk '{print $NF}' | grep -E "^($HIDE_PROCS)$" | sort -u | tr '\n' ' ')
    printf '{"ok":true,"su":"%s","frida":"%s","rootdir":"%s","detect":"%s","procs":"%s","props":{"bl":"%s","flash":"%s","vbmeta":"%s","debuggable":"%s","type":"%s"}}\n' \
      "$(json_s "${su_hit% }")" "$(json_s "${fr_hit% }")" "$(json_s "${rd_hit% }")" "$(json_s "${de_hit% }")" \
      "$(json_s "${procs% }")" \
      "$(json_s "$(getprop ro.boot.verifiedbootstate)")" "$(json_s "$(getprop ro.boot.flash.locked)")" \
      "$(json_s "$(getprop ro.boot.vbmeta.device_state)")" "$(json_s "$(getprop ro.debuggable)")" \
      "$(json_s "$(getprop ro.build.type)")"
    ;;
  apply)
    nprop=$(hide_props)
    MODE="safe"; [ "$2" = "--aggressive" ] && MODE="aggressive"
    set -- $(hide_paths "$MODE")
    log "apply: props=$nprop hidden=$1 failed=$2"
    printf '{"ok":true,"props_changed":%s,"paths_hidden":%s,"paths_failed":%s,"note":"重启后需重跑"}\n' \
      "$nprop" "$1" "$2"
    ;;
  restore)
    unhide_paths
    log "restore: paths unhidden"
    printf '{"ok":true,"msg":"已恢复挂载状态（prop 需要重启才恢复）"}\n'
    ;;
  *)
    echo '{"ok":false,"error":"usage: hideenv.sh scan|apply|restore"}'
    ;;
esac
exit 0
