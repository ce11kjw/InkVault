# 更新日志

## v1.0.1 (2026-10-17)

第四轮全量审计（剩余脚本逐行）修复。

### 严重
- `settings.sh`: 写入改用 awk 重写文件（原 `sed "s|k=v|"` 中 val 含 `&`/`|`/`\` 会写坏配置）
  + key 白名单 + val 字符白名单 + clean_mode 限定 light|deep
- `sysinfo.sh`: 全面 JSON 转义（fingerprint 含 `"`/`\` 时原会输出非法 JSON → 系统信息页白屏）
- `index.html`: resetSSAID / applySpoof / runClean 增加参数白名单校验（纵深防御）

### 中等
- `settings.sh`: read_setting 改用 awk 精确匹配（原 grep -E 受正则元字符影响）
- `index.html`: esc() 补单引号转义；escA() 补反斜杠与双引号转义
- `sysinfo.sh`: uptime / ram / battery 增加空值兜底
- `index.html`: 新增 safeParse()，7 处裸 JSON.parse 全部替换

## v1.0 (2026-10-17)

首个版本：Fish 工具箱 + CITADEL-Menu 合并。

### 新增
- 游戏清理引擎（16 款游戏，数据驱动）
- 指纹伪装 / 恢复（希腊字母同形字方案）
- 随机设备 ID / SSAID 重置
- 隐藏 BL（15 条 prop）+ 设备安全检测
- 系统垃圾清理 + 作弊驱动残留清理
- WebUI「工具箱」页签
- 开机自动重应用 BL 伪装

### 合并自
- Fish 的清理工具箱 4.8：[1-13] 游戏清理、[82] 系统垃圾、[84] 驱动清理、[93] 隐藏 BL、指纹修改
- CITADEL-Menu v3.0：机型伪装（21 预设）、SSAID 管理、进程监听、WebUI 框架

### 未合并（原版为空壳/彩蛋）
- [94] 仅打开网页、[95] 仅打开网盘链接、[96] 无实质功能、[97] 实为小游戏

### 安全化改造
- Fish 原版 `find /data -name "*.log" -delete` → 限定安全目录
- `rm -rf /data/local/tmp/*` → 白名单式（只删 *.tmp 等）
- 所有外部输入加白名单校验（防命令注入）
- SSAID 修改改为精确行替换 + 先备份
