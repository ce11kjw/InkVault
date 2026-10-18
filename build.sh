#!/bin/bash
# 打包墨匣 InkVault 模块
set -e
cd "$(dirname "$0")"
V=$(grep '^version=' module.prop | cut -d= -f2)
OUT="../InkVault-${V}.zip"
rm -f "$OUT"
# 校验
for f in scripts/*.sh service.sh; do sh -n "$f" || { echo "语法错误: $f"; exit 1; }; done
find . -name '*.bak*' -delete 2>/dev/null || true
zip -r -q "$OUT" . -x '.git/*' -x 'build.sh' -x 'vendor/*' -x '.gitignore' -x '*.md'
echo "打包完成: $OUT ($(stat -c%s "$OUT") 字节)"
unzip -l "$OUT" | tail -20
