# 墨匣 InkVault

手游清理 + 设备伪装一体化模块（Magisk / KernelSU / APatch）

融合 **Fish 的清理工具箱 4.8** 与 **CITADEL-Menu (呆呆)** 的全部有效功能，
去重复后重写为数据驱动结构，并提供 WebUI 面板。

## 功能

### 游戏清理（16 款）
无畏契约 / 三角洲行动 / 和平精英 / 暗区突围(国服+国际) / 王者荣耀 / 使命召唤 /
穿越火线 / 失控进化 / 火影忍者 / 热血合击 / PUBG 国际服·日韩服·韩服·越南服·日服

- 轻度：只清 cache / code_cache
- 深度：清全部缓存与日志，**保留防重下凭证**（Manifest / Version.cfg / PlayerData 等）
- 自动处理多用户目录 `/data/user/*/` 与多存储 `/storage/emulated/*/`

### 设备标识
- **指纹伪装**：把 fingerprint 中 N 个拉丁字母替换为希腊同形字（Fish 同款方案）
- **一键恢复**：从备份还原原始指纹
- **随机设备 ID**：随机化 serialno / meid
- **SSAID 管理**：查看 / 随机重置各游戏的应用专属 ID

### 环境伪装
- **隐藏 BL**：15 条 prop 伪装成已锁定（每次开机自动重应用）
- **安全检测**：检查 root / Frida / Xposed / 模拟器 / 检测类应用

### 系统清理
- **系统垃圾**：缓存 / ANR / tombstones / dropbox / 下载临时文件
- **驱动残留**：QX / Orange 等外挂驱动与作弊配置清理

## 安装

1. 下载 `InkVault-v1.0.zip`
2. Magisk / KernelSU / APatch → 模块 → 从本地安装
3. 重启后在模块管理器中打开 WebUI

## 结构

```
InkVault/
├── module.prop           模块信息
├── service.sh            开机服务
├── scripts/
│   ├── games.db          游戏数据表（包名 + 清理路径）
│   ├── games.sh          游戏清理引擎
│   ├── fp.sh             指纹伪装 / 恢复
│   ├── envhide.sh        隐藏 BL / 安全检测
│   ├── sysclean.sh       系统垃圾 / 驱动清理
│   ├── ssaid.sh          SSAID 管理
│   ├── spoof.sh          机型伪装（21 预设）
│   ├── cleaner.sh        兼容层（转调 games.sh）
│   ├── monitor.sh        进程监听（自动清理）
│   ├── settings.sh       设置读写
│   └── sysinfo.sh        系统信息
└── webroot/
    ├── index.html        WebUI 面板
    └── icons/            游戏图标
```

## 说明

- 所有脚本输出 JSON，便于 WebUI 解析
- 清理逻辑集中在 `games.sh`，`cleaner.sh` 仅作兼容转发
- 指纹/机型伪装均为**重启后生效**（写 system.prop，不污染运行态）

## 致谢

- **Fish**（Fish 的清理工具箱）
- **呆呆**（CITADEL-Menu / QQ 891354018）

## 许可

仅供个人学习与设备管理使用。
