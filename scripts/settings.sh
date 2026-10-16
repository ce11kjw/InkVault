#!/system/bin/sh
# 模块设置管理脚本
# 作者: 呆呆 | QQ:891354018 | 群:774886621
# 用法:
#   sh settings.sh get              获取所有设置（JSON）
#   sh settings.sh set <key> <val>  设置单项
#
# 配置项:
#   auto_clean_on_boot          开机自动清理 (0/1)
#   auto_clean_on_codev_start   游戏启动时自动清理 (0/1)
#   auto_clean_on_codev_stop    游戏退出时自动清理 (0/1)
#   clean_mode                  清理模式 (light/deep)

MOD_DIR="/data/adb/modules/webui_info"
SETTINGS_FILE="$MOD_DIR/settings.conf"
ACTION="$1"
KEY="$2"
VAL="$3"

read_setting() {
    local key="$1"
    [ -f "$SETTINGS_FILE" ] && grep -E "^${key}=" "$SETTINGS_FILE" | head -1 | cut -d'=' -f2-
}

write_setting() {
    local key="$1"
    local val="$2"
    [ ! -f "$SETTINGS_FILE" ] && touch "$SETTINGS_FILE"
    if grep -q "^${key}=" "$SETTINGS_FILE" 2>/dev/null; then
        sed -i "s|^${key}=.*|${key}=${val}|" "$SETTINGS_FILE"
    else
        echo "${key}=${val}" >> "$SETTINGS_FILE"
    fi
}

case "$ACTION" in
    get)
        AUTO_BOOT=$(read_setting auto_clean_on_boot)
        AUTO_START=$(read_setting auto_clean_on_codev_start)
        AUTO_STOP=$(read_setting auto_clean_on_codev_stop)
        MODE=$(read_setting clean_mode)
        LAST_CLEAN=$(read_setting last_clean_time)
        CUR_SPOOF=$(read_setting current_spoof)
        CUR_LABEL=$(read_setting current_spoof_label)
        ORIG_MODEL=$(read_setting orig_model)

        # 默认值
        [ -z "$AUTO_BOOT" ] && AUTO_BOOT="1"
        [ -z "$AUTO_START" ] && AUTO_START="0"
        [ -z "$AUTO_STOP" ] && AUTO_STOP="0"
        [ -z "$MODE" ] && MODE="deep"

        printf '{"auto_clean_on_boot":"%s","auto_clean_on_codev_start":"%s","auto_clean_on_codev_stop":"%s","clean_mode":"%s","last_clean":"%s","current_spoof":"%s","current_spoof_label":"%s","orig_model":"%s"}\n' \
            "$AUTO_BOOT" "$AUTO_START" "$AUTO_STOP" "$MODE" \
            "${LAST_CLEAN:-从未}" "${CUR_SPOOF:-none}" "${CUR_LABEL:-原机型}" "${ORIG_MODEL:-未知}"
        ;;

    set)
        if [ -z "$KEY" ] || [ -z "$VAL" ]; then
            echo '{"ok":false,"error":"missing key or value"}'
            exit 1
        fi
        case "$KEY" in
            auto_clean_on_boot|auto_clean_on_codev_start|auto_clean_on_codev_stop|clean_mode)
                write_setting "$KEY" "$VAL"

                # 副作用：切换 start/stop 开关时自动启停监听
                case "$KEY" in
                    auto_clean_on_codev_start|auto_clean_on_codev_stop)
                        START_EN=$(read_setting auto_clean_on_codev_start)
                        STOP_EN=$(read_setting auto_clean_on_codev_stop)
                        if [ "$START_EN" = "1" ] || [ "$STOP_EN" = "1" ]; then
                            sh "$MOD_DIR/scripts/monitor.sh" start >/dev/null 2>&1
                        else
                            sh "$MOD_DIR/scripts/monitor.sh" stop >/dev/null 2>&1
                        fi
                        ;;
                esac

                printf '{"ok":true,"key":"%s","val":"%s"}\n' "$KEY" "$VAL"
                ;;
            *)
                echo '{"ok":false,"error":"unknown key"}'
                exit 1
                ;;
        esac
        ;;

    *)
        echo '{"ok":false,"error":"unknown action - use: get | set"}'
        exit 1
        ;;
esac
