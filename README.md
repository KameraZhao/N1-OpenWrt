# 斐讯 N1 旁路由固件

基于 ImmortalWrt 25.12 和 Flippy 6.12.116 内核构建。默认管理地址为 **192.168.123.99/24**，上游网关和 DNS 为 **192.168.123.11**。首次使用建议全新刷写；将 N1 与上游路由连接到同一局域网。客户端需自行将网关指向 N1 才会经过旁路由；请确保地址未被占用。

默认关闭 LAN 的 DHCP、IPv6 DHCP 和路由通告，由主路由管理地址分配。IPv6 客户端、网关和前缀取决于上游网络；如需 IPv6 流量经过旁路由，还需在主路由或客户端上配置相应的 IPv6 路由，不能仅依靠 IPv4 网关设置。

内置 luci-app-honk（含 Honk 核心和 Doona）、Docker 与 luci-app-dockerman、Argon 主题及配置、luci-app-amlogic、Samba。Honk 首次使用前需在 `/etc/honk/config.d/node.dae` 配置节点和订阅。

构建会检查 Flippy 内核的 `BPF_EVENTS`、`DEBUG_INFO_BTF`、`XDP_SOCKETS` 和 OpenWrt 的 `vmlinux-btf-builtin` 配置。该包是依赖占位包，BTF 由实际运行内核提供；刷机后可检查 `/sys/kernel/btf/vmlinux`、`/proc/config.gz` 并实测 Honk 和 Docker。第三方内核与 OpenWrt 软件包的内核模块兼容性仍需在设备上验证。

固件由 GitHub Actions 手动或定期构建，产物发布到 Releases。项目基于 [ImmortalWrt](https://github.com/immortalwrt/immortalwrt)、[Honk](https://github.com/QiuSimons/luci-app-honk) 和 [ophub 打包脚本](https://github.com/ophub/amlogic-s9xxx-openwrt)。
