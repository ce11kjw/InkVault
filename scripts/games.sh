#!/system/bin/sh
# 游戏缓存清理引擎 —— 数据驱动（games.db）
# 用法:
#   games.sh list                列出游戏+安装状态(JSON)
#   games.sh clean <id> [light]  清理指定游戏(JSON)
#   games.sh cleanall [light]    清理全部已安装游戏
D="$(cd "$(dirname "$0")" && pwd)"
DB="$D/games.db"
LOG="/data/local/tmp/fusion_games.log"
# 深度清理时保留的防重下凭证
KEEP='Manifest_UFSFiles_Android.txt|NotAllowedUnattendedBugReports|Version\.cfg|ClearFlag_|BagSkinCache_|PlayerData\.cfg|PCache\.meta|Manifest\.ini'
log(){ echo "[$(date '+%F %T')] $*" >> "$LOG"; }
installed(){ pm list packages 2>/dev/null | grep -q "package:$1$"; }

clean_one(){
  gid="$1"; mode="${2:-deep}"
  line=$(grep "^${gid}|" "$DB")
  [ -z "$line" ] && { echo "{\"ok\":false,\"error\":\"unknown game\"}"; return 1; }
  name=$(echo "$line" | cut -d'|' -f2)
  pkg=$(echo "$line" | cut -d'|' -f3)
  subs=$(echo "$line" | cut -d'|' -f4- | tr '|' ' ')
  installed "$pkg" || { echo "{\"ok\":false,\"game\":\"$name\",\"error\":\"未安装\"}"; return 1; }
  before=$(du -sk "/data/user/0/$pkg" 2>/dev/null | awk '{print $1}')
  # 内部数据 /data/user/*/<pkg>/<sub>
  for u in /data/user/*/; do
    u="${u%/}"
    for s in $subs; do
      case "$s" in *UE4Game*|*Saved*) [ "$mode" = "light" ] && continue;; esac
      [ -e "$u/$pkg/$s" ] && rm -rf "$u/$pkg/$s" 2>/dev/null
    done
    rm -rf "$u/cn.binmeng.miui/files/Android/data/$pkg" 2>/dev/null
  done
  # 外部数据 /storage/emulated/*/Android/{data,media,obb}/<pkg>
  for st in /storage/emulated/*/; do
    for base in Android/data Android/media Android/obb; do
      ext="$st$base/$pkg"; [ -d "$ext" ] || continue
      if [ "$mode" = "light" ]; then
        rm -rf "$ext/cache" "$ext/code_cache" 2>/dev/null
      else
        if [ -d "$ext/files" ]; then
          find "$ext/files" -mindepth 1 -maxdepth 1 2>/dev/null | while read -r f; do
            echo "$(basename "$f")" | grep -qE "$KEEP" || rm -rf "$f" 2>/dev/null
          done
        fi
        rm -rf "$ext/cache" "$ext/code_cache" 2>/dev/null
      fi
    done
  done
  after=$(du -sk "/data/user/0/$pkg" 2>/dev/null | awk '{print $1}')
  delta=$(( ${before:-0} - ${after:-0} )); [ $delta -lt 0 ] && delta=0
  log "clean $name mode=$mode freed=${delta}KB"
  printf '{"ok":true,"game":"%s","pkg":"%s","mode":"%s","freed_kb":%d,"time":"%s"}\n' "$name" "$pkg" "$mode" "$delta" "$(date '+%F %T')"
}

case "$1" in
  list)
    printf '['
    sep=""
    while IFS= read -r l; do
      [ -z "$l" ] && continue
      id=$(echo "$l" | cut -d'|' -f1); nm=$(echo "$l" | cut -d'|' -f2); pk=$(echo "$l" | cut -d'|' -f3)
      if installed "$pk"; then ins=true; else ins=false; fi
      printf '%s{"id":"%s","name":"%s","pkg":"%s","installed":%s}' "$sep" "$id" "$nm" "$pk" "$ins"
      sep=","
    done < "$DB"
    printf ']\n'
    ;;
  clean) clean_one "$2" "$3" ;;
  cleanall)
    while IFS='|' read -r id rest; do clean_one "$id" "${2:-deep}"; done < "$DB"
    ;;
  *) echo '{"ok":false,"error":"usage: games.sh list|clean <id>|cleanall"}' ;;
esac
exit 0
