# ImmortalWrt for 友善 NanoPi R1S H5（保留板载 WiFi）

用 GitHub Actions 云端编译 **ImmortalWrt 25.12.2**（内核 6.12）固件，目标平台 `sunxi/cortexa53`，
并**保留板载 WiFi**。

## 这块板子的 WiFi 到底是什么

| 项目 | 值 |
|---|---|
| 板载 WiFi 芯片 | **Realtek RTL8189ETV**（不是 NanoPi R1 上那颗博通 AP6212） |
| 接口 | SDIO（挂在 `mmc1` 上，设备树里有 `rtl8189etv: wifi@1`） |
| 频段 | 2.4GHz 802.11b/g/n，1x1 |
| 天线 | IPX/U.FL 外置天线接口 |
| 驱动 | **树外驱动 `kmod-rtl8189es`**（Realtek 原厂驱动，上游内核里没有） |
| 设备名 | `friendlyarm,nanopi-r1s-h5` |

关键点：**内核/官方镜像默认不带这颗芯片的驱动**。不显式编译 `kmod-rtl8189es`，
刷完就是一台「有无线硬件但看不到无线菜单」的路由器。

## 目录结构

```
.
├── .github/workflows/build.yml     # 云端编译工作流
├── configs/nanopi-r1s-h5.config    # 编译配置片段（追加到 .config）
├── diy-part1.sh                    # feeds 更新前执行（默认空操作，留扩展位）
├── diy-part2.sh                    # 把 files/ 注入源码树
├── files/                          # 直接进固件的文件覆盖层
│   └── etc/
│       ├── init.d/nanopi-wifi      # 首次开机设置监管域/SSID（默认不自动开射频）
│       └── uci-defaults/99-nanopi-init
└── README.md
```

## 怎么用

1. **Fork** 本仓库到你自己的 GitHub 账号。
2. 仓库 **Settings → Actions → General → Workflow permissions** 选
   **Read and write permissions**（不然发布 Release 会失败）。
3. 进 **Actions** 标签页 → 左侧选 `Build ImmortalWrt (NanoPi R1S H5)` → **Run workflow**。
4. 等 1~2 小时，产物出现在该次运行的 **Artifacts** 里，同时自动发一个 **Release**。

产物文件：

```
immortalwrt-25.12.2-sunxi-cortexa53-friendlyarm_nanopi-r1s-h5-ext4-sdcard.img.gz
immortalwrt-25.12.2-sunxi-cortexa53-friendlyarm_nanopi-r1s-h5-squashfs-sdcard.img.gz
```

## 刷机

1. 解压 `.img.gz` 得到 `.img`（注意：**先解压再刷**，不要拿 `.gz` 直刷）。
2. 用 **Rufus**（Windows）或 **balenaEtcher** 把 `.img` 写入 TF 卡。
3. TF 卡插回 R1S H5，上电。默认管理地址 `http://192.168.1.1`，用户名 `root`，密码为空。
4. 网口映射：`eth0` = WAN，`eth1` = LAN。

## 开启 WiFi

出于稳定考虑，固件**默认不自动打开射频**（见下方「已知风险」）。开机后：

- **网页**：LuCI → 网络 → 无线 → 点 `radio0` 的「启用」，改 SSID / 密码，保存应用。
- **命令行**：

```sh
uci set wireless.radio0.disabled='0'
uci set wireless.default_radio0.ssid='MyWiFi'
uci set wireless.default_radio0.encryption='psk2'
uci set wireless.default_radio0.key='你的密码'
uci commit wireless
wifi reload
```

验证：

```sh
dmesg | grep -i -E "rtl8189|8189es"
iw dev                     # 应能看到 wlan0
iwinfo                     # 查看射频与信号
```

## 已知风险与应对

**RTL8189ES 是树外驱动，社区长期反馈它在较新内核上开 AP 模式可能导致 kernel panic / 重启循环。**

| 方案 | 内核 | 板载 WiFi | 说明 |
|---|---|---|---|
| **ImmortalWrt 25.12.2**（本项目） | 6.12 | 驱动为 2025-09-27 快照，较新，需实测 | 软件源最新、插件最全 |
| ImmortalWrt 24.10.x | 6.6 | 同上 | 更保守一点 |
| ImmortalWrt 23.05.x | 5.15 | 社区反馈：客户端/扫描可用，AP 不稳 | 需要开 AP 时更稳的是下面这行 |
| ImmortalWrt 21.02.x | 5.4 | 社区反馈：AP + 客户端都稳定 | 但软件源已 EOL，插件旧 |

**如果 25.12 上开 AP 会崩**，按这个顺序处理：

1. 先只当 **STA（客户端）** 用 —— 拿它去连上级 WiFi，稳；
2. 把 `build.yml` 里的 `REPO_BRANCH` 改成 `v23.05.7` 或 `openwrt-23.05` 重新编译；
3. 干脆插一个 **USB 无线网卡**（RTL8811CU / MT7601U 之类），驱动更成熟；
4. 板载 WiFi 只当「有就行」，主力网络走有线双千兆口。

## 从网页升级 / 保留配置

已经跑本项目固件时，LuCI → 系统 → 备份/升级固件，直接上传新的
`*-sdcard.img.gz`（**不用解压**），勾选「保留配置」即可热升级。

## 定制

- 加/减软件包：改 `configs/nanopi-r1s-h5.config`，`CONFIG_PACKAGE_xxx=y`。
  写错的选项会被 `make defconfig` 静默忽略，不会导致编译失败。
- 改默认配置：往 `files/` 里加文件，会原样覆盖到固件根文件系统。
- 换版本：改 `build.yml` 里的 `REPO_BRANCH`（`v25.12.2` / `openwrt-25.12` / `master`）。
