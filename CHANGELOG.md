# 更新日志

## v1.1.0 (2026-10-18)

针对真实反作弊（Duck Detector）检测报告的定向加固。

### 新增：SELinux 策略硬化（`sepolicy.sh`）
**这是本次最重要的修复。** 实测发现 APatch/KernelSU 的策略生成器会把
`ksu_file` / `magisk_file` 以 `allow appdomain <type> *` 的形式全量放行
（ksu_file 覆盖 **107 个 class**，magisk_file 6 个），导致：

```
untrusted_app -> ksu_file:file read  =  Allowed   ← 反作弊判为 root
```

任何普通 App 通过 `selinux_check_access` 都能查到。修复：
- `scan`：统计泄漏规则数
- `fix`：生成逐 class 的 deny 语句并 `magiskpolicy --live` 热加载（**立即生效，无需重启**）
- `restore`：从备份还原原始策略

**零风险依据**：磁盘上没有文件实际使用 `ksu_file` 标签
（APatch 自身用的是 `adb_data_file`），删除规则不影响任何功能。
实测：107→0，系统 su / pm / SELinux Enforcing 均正常。

### 新增：环境隐藏（`hideenv.sh`）
基于真机实测暴露项针对性隐藏：
- `su` 二进制（/system/bin/su 等 6 处）
- Frida（/data/local/tmp/frida-server 等 5 处）
- Xposed 静态特征（XposedBridge.jar 等 3 处）
- 分层设计：默认只隐藏「安全层」，`--aggressive` 才动 root 框架目录
  （**绝不碰 /data/adb/modules**，那里有 26 个模块）

### 新增：开机自动重应用
- `auto_hide_env`：开机后自动隐藏环境
- `auto_sepolicy_fix`：开机后自动硬化 SELinux 策略
  （内核策略每次重启都会重置，必须开机重跑）

### 修复
- WebUI 缺失 6 个函数定义（tbHideEnv* / tbSepolicy*）——按钮存在但无实现

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
