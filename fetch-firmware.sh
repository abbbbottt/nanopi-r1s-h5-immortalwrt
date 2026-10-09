#!/bin/bash
# 通过 GitHub API 的 asset 端点下载 Release 固件
# 背景：沙箱代理对 github.com 时通时断（502），但 api.github.com 稳定可用
# 注意：Windows 上 python 输出是 \r\n，必须 tr -d '\r'，否则 curl 报 URL malformed
set -u
TOKEN="${GH_TOKEN:?需要 GH_TOKEN}"
R="abbbbottt/nanopi-r1s-h5-immortalwrt"
TAG="v25.12.2-20261009-2"
P="immortalwrt-sunxi-cortexa53-friendlyarm_nanopi-r1s-h5"
DIR="C:/Users/csci/WorkBuddy/2026-10-09-09-14-36/firmware"
mkdir -p "$DIR"
cd "$DIR" || exit 1

api() { curl -s -H "Authorization: token $TOKEN" -H "Accept: application/vnd.github+json" "$@"; }

# 抓一次 release 元数据，取出「文件名 -> id / size」映射
api "https://api.github.com/repos/$R/releases/tags/$TAG" | tr -d '\r' > meta.json
echo "assets:"
python -c "
import json
d=json.load(open('meta.json',encoding='utf-8'))
for a in d['assets']:
    print(f\"  {a['name']}  id={a['id']}  size={a['size']}\")
"

for f in "$P-ext4-sdcard.img.gz" "$P-squashfs-sdcard.img.gz" "sha256sums" "$P.manifest"; do
  read -r aid want < <(python -c "
import json
d=json.load(open('meta.json',encoding='utf-8'))
for a in d['assets']:
    if a['name']=='$f': print(a['id'], a['size'])
")
  if [ -z "${aid:-}" ]; then echo "!! 找不到 asset: $f"; continue; fi
  echo ">>> $f (asset $aid, 需要 $want 字节)"

  for attempt in $(seq 1 40); do
    curl -L -C - --max-time 3000 --speed-time 120 --speed-limit 2048 \
      -H "Authorization: token $TOKEN" \
      -H "Accept: application/octet-stream" \
      -o "$f" -s \
      "https://api.github.com/repos/$R/releases/assets/$aid"
    code=$?
    have=$(stat -c %s "$f" 2>/dev/null || echo 0)
    printf "    attempt %2d: exit=%d  %s / %s 字节 (%.1f%%)\n" \
      "$attempt" "$code" "$have" "$want" "$(python -c "print($have*100.0/$want)")"
    if [ "$have" = "$want" ]; then echo "    >>> 完成"; break; fi
    sleep 5
  done
done

echo "=== 最终文件 ==="
ls -lh
echo "=== SHA256 校验 ==="
grep -E "ext4-sdcard|squashfs-sdcard" sha256sums > check.txt 2>/dev/null && sha256sum -c check.txt 2>&1
echo "=== DONE ==="
