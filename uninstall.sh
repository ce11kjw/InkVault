#!/system/bin/sh
# 卸载清理：恢复本模块改过的系统状态

MODDIR="${0%/*}"
LOG="/data/local/tmp/inkvault_uninstall.log"

log(){ echo "[$(date '+%F %T')] $*" >> "$LOG" 2>/dev/null; }

log "===== 开始卸载清理 ====="

# 1. 恢复机型伪装（如果有）
if [ -f "$MODDIR/scripts/spoof.sh" ]; then
    sh "$MODDIR/scripts/spoof.sh" apply __restore__ >/dev/null 2>&1
    log "机型伪装已恢复"
fi

# 2. 恢复指纹（如果有备份）
if [ -f "$MODDIR/scripts/fp.sh" ]; then
    sh "$MODDIR/scripts/fp.sh" restore >/dev/null 2>&1
    log "指纹已尝试恢复"
fi

# 3. 移除 chroot 垫片（避免留下孤儿文件）
if [ -f "$MODDIR/scripts/chroot-wrap.sh" ]; then
    OUT=$(sh "$MODDIR/scripts/chroot-wrap.sh" list 2>/dev/null)
    echo "$OUT" | grep -q '"wrapped"' && log "存在 chroot 垫片，请手动处理（scripts/chroot-wrap.sh list）"
fi

# 4. 停止 monitor.sh 后台进程
if [ -f "$MODDIR/scripts/monitor.sh" ]; then
    sh "$MODDIR/scripts/monitor.sh" stop >/dev/null 2>&1
    log "monitor 已停止"
fi

# 5. 清理运行时数据（保留 /data/adb/fusion 里的备份，用户可能还需要）
rm -f /data/local/tmp/webui_service.log 2>/dev/null
rm -f /data/local/tmp/fusion_envhide.log 2>/dev/null
rm -f /data/local/tmp/fusion_sepolicy.log 2>/dev/null
log "临时日志已清理"

# 6. 提示
log "⚠ 以下内容需要手动处理（本模块未自动改动它们）："
log "  - ALING_MAC / ALING_Serialno / SELinux-LING 是独立模块，不受影响"
log "  - SELinux 硬化规则会在重启后自动恢复（内核策略不持久）"
log "  - /data/adb/fusion 下的备份文件保留，可手动删除"
log "===== 卸载清理完成 ====="

exit 0
