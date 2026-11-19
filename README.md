# 斐讯 N1 旁路由固件

## 旁路由设置

将 N1 与上游路由接到同一局域网。N1 的管理地址为 **192.168.123.99/24**，上游网关为 **192.168.123.11**，DNS 为 **223.5.5.5** 和 **119.29.29.29**。

N1 强制提供 DHCPv4，租期 12 小时，地址池为 `192.168.123.100–249`，给客户端下发 N1 作为网关和 DNS。请先关闭主路由在该网段的 DHCPv4，避免两台设备同时发放地址。LAN 开启 IPv4 动态伪装，关闭 FullCone NAT 和流量卸载。

LAN6 使用 DHCPv6 客户端接收上游 IPv6 配置，忽略上游 DNS。LAN 启用 RA 服务器模式，关闭 SLAAC、DHCPv6 服务和 NDP 代理。RA 路由器生存时间为 0，客户端的 IPv6 地址和默认路由依赖上游路由。

## 安装软件和更新 Honk

LuCI 的「系统 → 软件包」支持更新列表、安装普通应用以及更新 `honk`、`luci-app-honk` 和 `luci-i18n-honk-zh-cn`。也可以在 N1 上运行：

```sh
apk update
apk upgrade honk luci-app-honk luci-i18n-honk-zh-cn
```

如果 Honk 已在运行，更新后在 LuCI 中重启 Honk 服务。节点和分流配置保存在 `/etc/honk/`。

已经安装本项目旧版 `25.12-SNAPSHOT` 的设备，可将 Releases 中的 `repair-apk-sources.sh` 上传到 N1 后，以 root 身份运行 `sh /tmp/repair-apk-sources.sh`。脚本验证索引签名后才切换软件源，并备份原列表。更新 Honk 和修复软件源均可在原系统完成。

软件源包含与 ImmortalWrt 25.12 稳定版对应的应用包和本仓库签名的 Honk 包。Flippy 内核使用自身的模块；ImmortalWrt 官方 kmod 的内核 ABI 与它不同。

## 自动构建

GitHub Actions 每周三、周六北京时间 04:23 构建，也可手动触发。每次选择已有软件源的最新 ImmortalWrt 25.12 稳定版和上游已发布的 Honk 版本，固件和签名 APK 按构建日期发布到 Releases。

固件保留 Docker 和 Dockerman、Argon 及其设置、Amlogic 管理和 Samba。Flippy 内核固定为 6.12.116，构建时检查 `BPF_EVENTS`、`DEBUG_INFO_BTF`、`XDP_SOCKETS` 和 `vmlinux-btf-builtin`。刷机后可通过 `/sys/kernel/btf/vmlinux` 和 `/proc/config.gz` 核对运行内核。

Honk 源使用仓库的 `HONK_APK_SIGNING_KEY` Actions secret 签名。其公钥随固件安装。维护此软件源时需保留同一密钥，已安装的 N1 才能继续验证后续更新。
