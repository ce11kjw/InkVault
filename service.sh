#!/system/bin/sh
# 模块开机服务
# 作者: 呆呆 | QQ:891354018 | 群:774886621

MODDIR="${0%/*}"
LOGFILE="/data/local/tmp/webui_service.log"
SETTINGS_FILE="$MODDIR/settings.conf"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOGFILE"
}

# 等待开机完成（最多 5 分钟，避免异常开机时永久挂住）
WAIT=0
until [ "$(getprop sys.boot_completed)" = "1" ]; do
    sleep 2
    WAIT=$((WAIT+1))
    [ $WAIT -ge 150 ] && log "等待开机超时(300s)，继续执行" && break
done
sleep 5

log "===== 开机服务启动 ====="

# 准备融合工具目录 + 脚本可执行
mkdir -p /data/adb/fusion /data/local/tmp 2>/dev/null
chmod 755 "$MODDIR/scripts/"*.sh 2>/dev/null

# 重应用 BL 伪装（每次开机）
sh "$MODDIR/scripts/envhide.sh" hide-bl >/dev/null 2>&1
log "BL 伪装已重应用"

# 环境隐藏 + SELinux 策略硬化（若开启）
get_setting_pre() {
    grep "^$1=" "$SETTINGS_FILE" 2>/dev/null | head -1 | cut -d'=' -f2-
}
if [ "$(get_setting_pre auto_hide_env)" = "1" ]; then
    sh "$MODDIR/scripts/hideenv.sh" apply >/dev/null 2>&1
    log "环境隐藏已重应用"
fi
if [ "$(get_setting_pre auto_sepolicy_fix)" = "1" ]; then
    sh "$MODDIR/scripts/sepolicy.sh" fix >/dev/null 2>&1
    log "SELinux 策略硬化已重应用"
fi

# 1. 应用机型伪装（如果有保存）
log "执行机型伪装恢复"
sh "$MODDIR/scripts/spoof.sh" boot_apply >/dev/null 2>&1

# 2. 优化 inotify 参数
log "优化 inotify 参数"
sh "$MODDIR/scripts/cleaner.sh" inotify >/dev/null 2>&1

# 3. 开机自动清理（如果开启）
get_setting() {
    grep "^$1=" "$SETTINGS_FILE" 2>/dev/null | head -1 | cut -d'=' -f2-
}

# 默认开机自动清理是开启的
BOOT_CLEAN=$(get_setting auto_clean_on_boot)
[ -z "$BOOT_CLEAN" ] && BOOT_CLEAN=1

if [ "$BOOT_CLEAN" = "1" ]; then
    MODE=$(get_setting clean_mode)
    log "开机自动清理（模式: ${MODE:-deep}）"
    sh "$MODDIR/scripts/cleaner.sh" "${MODE:-deep}" >/dev/null 2>&1
fi

# 4. 启动进程监听服务（如果有任意一个自动清理开关开启）
START_EN=$(get_setting auto_clean_on_codev_start)
STOP_EN=$(get_setting auto_clean_on_codev_stop)
if [ "$START_EN" = "1" ] || [ "$STOP_EN" = "1" ]; then
    log "启动进程监听服务"
    sh "$MODDIR/scripts/monitor.sh" start &
fi

log "===== 开机服务初始化完成 ====="
