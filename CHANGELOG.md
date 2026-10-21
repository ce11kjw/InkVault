# 更新日志

## v1.4.1 (2026-10-22)

### 🔴 修复：激进隐藏会把 LSPosed 打死（严重）

**现象**：点了环境隐藏的「激进模式」之后，LSPosed 管理器直接失联，
模块作用域丢失，日志狂刷：
```
E/LSPosed: Failed with No such file or directory(2): open /data/adb/lspd/monitor
```

**根因**：`PATHS_RISKY` 里包含 `/data/adb/lspd`，激进模式对其执行
```
mount -t tmpfs -o mode=000 tmpfs /data/adb/lspd
```
把真实目录整个遮住 —— 而 LSPosed 的配置就存在 `/data/adb/lspd/config/*.db`。
LSPosed 读不到自己的配置，自然就废了。

**修复**：从 `PATHS_RISKY` 移除 `/data/adb/lspd`。
LSPosed 必须能读到自己的配置才能工作，藏它本身没有意义；
痕迹隐藏交给 Shamiko / HMA 更专业。

> 已经中招的：`umount /data/adb/lspd` 即可恢复（真实数据一直都在，只是被遮住）。

### 🟡 修复：`su` 检测恒报 visible（假阳性）

原实现用 **root shell** 判断：
```sh
[ -x /system/bin/su ] && suv="visible"
```
但 APatch 的 `/data/adb/ap/su_path` 本来就指着 `/system/bin/su`，
root 视角永远看得见 ⇒ 永远报 visible，与实际暴露面无关。

**修复**：先 root 视角初判，再用**非白名单普通 UID** 复核（真能在普通 app 视角 ls 到才算泄漏）。
实测修复后 `su: visible → hidden`（pathhide 本来是生效的，只是检测方法错了）。

### 🟡 修复：`frida` 检测把 0 字节占位当残留（假阳性）

隐藏机制是「mv 到 stash + 空文件占位 + chmod 000」，
但检测用 `ls /data/local/tmp/frida*` ⇒ 占位文件也让 `frida=1`。

**修复**：改用 `[ -s "$f" ]` 判非空，只认真实文件。
实测修复后 `frida: 1 → 0`。

### 📋 本版净效果（K60 Ultra / APatch 115357 真机实测）

| 字段 | 修复前 | 修复后 |
|---|---|---|
| `su` | visible ❌ | **hidden** ✅ |
| `frida` | 1 ❌ | **0** ✅ |
| `mount_leaks` | 0 | 0 ✅ |
| LSPosed | 失联 ❌ | **正常** ✅ |

---


## v1.4.0 (2026-10-21)

### 🔴 修复：路径隐藏完全失效（严重）

**现象**：`hideenv.sh apply` 始终返回 `hidden=0 failed=3`，三个路径无一隐藏成功。

**根因**（手机实测）：
```
mount: '/dev/null'->'/system/bin/su': No such file or directory
losetup: /dev/block/loop43=/dev/null: Invalid argument
```
1. Android toybox 的 `mount -o bind` 把源当 **loop 设备**处理，
   `/dev/null` 不是块设备 ⇒ 直接失败
2. `/` 是 **erofs 只读**，无法 remount rw

**修复**：按路径类型分三种策略
| 类型 | 方法 | 效果 |
|---|---|---|
| 目录（/data/adb/ap 等） | `mount -t tmpfs -o mode=000` | ✅ 内容清空，卸载后恢复 |
| /data 下文件（frida-server） | `mv` 到 `/data/adb/.inkvault_stash` + 空文件占位 + chmod 000 | ✅ 6B/644 → 0B/000，读取为空 |
| /system 下文件（su、XposedBridge.jar） | **无法隐藏**（只读分区） | ⚠️ 明确报告 skipped，提示需内核方案 |

**实测验证**（真机 K60 Ultra / APatch）：
- `/data/local/tmp/_test.bin`：6 bytes → 0 bytes，`cat` 返回空 ✅
- `/data/local/tmp/_testdir`：tmpfs 覆盖后目录为空，umount 后恢复 ✅

**注意**：`/system/bin/su`（334KB）在 APatch 下是真实文件且在只读分区，
**脚本层无法隐藏**。要隐藏它需要：
- SUSFS（KernelSU 模块）
- Shamiko（Zygisk 模块）
- 或用 `mount -t overlay` 做只读覆盖（需内核支持）

### 变更
- `hide_paths()` 重写（60 行 → 66 行，含详尽注释）
- `unhide_paths()` 同步支持恢复 stash 文件
- `apply` 输出新增 `paths_skipped` 字段
- 新增 `/data/adb/.inkvault_stash/` 作为隐藏文件暂存区


## v1.1.2 (2026-10-18)

**chroot 程序垫片** —— 不改任何第三方源码即可隐藏其挂载。

### 背景
上个版本解决了"自己写 chroot 启动器"的隔离问题，但用户还想用现成的 Mubuntu。
Mubuntu 的 `mount_chroot()` 直接在全局命名空间里 `mount`，且**源码全程没有 `unshare`**
⇒ 每次启动必然把 10 条挂载泄漏到 Android 全局。

### 方案：垫片（wrapper shim）
不改 Mubuntu 一个字节，只在它的入口路径上放一个同名包装器：

```
原文件 → 改名为 <name>.fusion-orig   （内容完全不变）
原路径 → 写入垫片：
         exec chroot-wrap.sh run <备份路径> "$@"
```

`chroot-wrap.sh run` 的执行链：
```
exec unshare -m sh -c '$MKP / && exec <原程序> "$@"'
```

**对照实测**（同一程序）：
| | 命名空间 | 调用后挂载 | app 视角泄漏 |
|---|---|---|---|
| 经垫片 | mnt:[4026536480]（新） | 189 → **189** | **0** |
| 直跑原程序 | mnt:[4026534147]（原） | 189 → **190** | 1 |

### 新增
- `scripts/chroot-wrap.sh` — `run` / `install` / `uninstall` / `list`
  - install 自动备份原文件（`.fusion-orig`）、保留 SELinux 上下文、写注册表 `/data/adb/fusion/wrapped.list`
  - uninstall 一键还原
- WebUI「chroot 程序垫片」区：套上 / 查看 / 移除

### 适用范围
任何会泄漏挂载的程序，例如：
- Mubuntu / Ubuntu-Chroot 等 chroot 模块的启动脚本
- 其他在全局命名空间 `mount` 的工具

## v1.1.1 (2026-10-18)

**隔离式 Linux chroot**：解决了 Mubuntu 等 chroot 模块挂载泄漏被反作弊发现的问题。

### 问题根因（实测定位）
Android 的 `/` 是 `shared` 传播类型。`unshare -m` 虽然创建了新挂载命名空间，
但**挂载事件仍会向外传播**到 Android 全局，导致：
- 普通应用可见 `/data/adb/mubuntu/rootfs/*` 共 10 条挂载
- Duck Detector 判定 `DANGER: Mount - direct root-managed mount token`

### 解决方案
```sh
unshare -m sh -c 'make-private / && mount --bind /dev $ROOTFS/dev && chroot $ROOTFS'
```
关键：`mount(NULL, "/", NULL, MS_PRIVATE|MS_REC, NULL)` — 把 root 设为 private，
阻断挂载事件传播。**toybox 的 mount 不支持传播类型参数**，故自带
`bin/make-private`（532KB 静态 ARM64 二进制）。

### 实测结果
```
启动前 191 条挂载 → 内层 194 条 → 退出后 191 条（零泄漏）
普通应用视角：0 条可见
chroot 内：/sdcard 正常、根目录正确切换
```

### 新增
- `scripts/chroot.sh` — status / check / run，把任意 rootfs 以隔离方式启动
- `bin/make-private` — 静态 ARM64 工具，设置挂载传播类型
- WebUI「隔离容器」区：环境检测 + 泄漏检查

### 内核能力说明
此内核 `CONFIG_NAMESPACES=y / CONFIG_UTS_NS=y / CONFIG_NET_NS=y`，
但 **无 `CONFIG_PID_NS` / `CONFIG_USER_NS`**。
不影响挂载隔离（只需 MNT 命名空间），但无法做 PID 隔离。

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
