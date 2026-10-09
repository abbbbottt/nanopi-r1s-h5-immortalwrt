#!/bin/bash
#
# diy-part2.sh
# 执行时机：feeds 安装完成、`make defconfig` 之前
#
# 作用：把本仓库的 files/ 目录注入源码树。
#       OpenWrt 构建时会自动把源码根目录下的 files/ 覆盖到固件根文件系统里。
#
set -e

OPENWRT_DIR="${GITHUB_WORKSPACE:-$(pwd)}/openwrt"
SRC_FILES="${GITHUB_WORKSPACE:-$(pwd)}/files"

echo "==> [diy-part2] 注入自定义文件覆盖层"

if [ -d "${SRC_FILES}" ]; then
    rm -rf "${OPENWRT_DIR}/files"
    cp -rf "${SRC_FILES}" "${OPENWRT_DIR}/files"
else
    echo "!! 未找到 ${SRC_FILES}，跳过"
    exit 0
fi

# Windows 上提交到 Git 的脚本很容易丢失可执行位，这里强制补齐
find "${OPENWRT_DIR}/files/etc" -type f \
     \( -path '*/uci-defaults/*' -o -path '*/init.d/*' \) \
     -exec chmod 0755 {} \; 2>/dev/null || true

echo "==> [diy-part2] 已注入以下文件:"
find "${OPENWRT_DIR}/files" -type f | sed "s#${OPENWRT_DIR}/##"

echo "==> [diy-part2] 完成"
