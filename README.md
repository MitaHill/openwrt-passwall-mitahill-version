# MitaHill PassWall

本仓库是基于 [Openwrt-Passwall/openwrt-passwall](https://github.com/Openwrt-Passwall/openwrt-passwall) 的 LuCI 分支，用于快速验证功能改进与问题修补。

当前分支针对已关闭的 [Openwrt-Passwall/openwrt-passwall2#665](https://github.com/Openwrt-Passwall/openwrt-passwall2/issues/665) 继续验证 IPv6 回环、核心持续满载及路由器半宕机问题，并已加入 IPv6 TProxy 更新时保留 WAN6 集合的修复。

## 发布状态

- 默认分支：[`main`](https://github.com/MitaHill/openwrt-passwall-mitahill-version/tree/main)
- 最新源码版本：[`26.9.16-1`](https://github.com/MitaHill/openwrt-passwall-mitahill-version/releases/tag/26.9.16-1)
- 当前改进：IPv6 TProxy 更新保留 WAN6 集合、修复 Sing-box URLTest 前置代理落地链路、改进并串行执行节点探测

后续版本请以 [最新发布页](https://github.com/MitaHill/openwrt-passwall-mitahill-version/releases/latest) 为准；发布页出现安装包后再下载。

## :mega: 公告

自 2026 年 6 月 1 日起，Xray Core 内部定时器已自动弃用 `allowInsecure`（跳过证书验证），并要求自签证书必须配置 `pinnedPeerCertSha256`（`pcs` 参数）。

若机场使用自签证书且未提供 `pcs` 参数，节点将无法正常连接。

**解决方法：**

- 向机场获取 `pinnedPeerCertSha256`（`pcs` 参数）；
- 或切换至 Sing-box Core。

## 📌 如何编译本仓库最新代码？

本仓库只提供 PassWall LuCI 代码；核心组件仍来自官方 `openwrt-passwall-packages` 仓库。

### 方法 1：通过 feeds 引入

执行 `./scripts/feeds update -a` 前，在 `feeds.conf.default` **顶部**加入：

```text
src-git passwall_packages https://github.com/Openwrt-Passwall/openwrt-passwall-packages.git;main
src-git passwall_luci https://github.com/MitaHill/openwrt-passwall-mitahill-version.git;main
```

随后照常更新并安装 feeds。

### 方法 2：直接克隆到源码树

在 `./scripts/feeds install -a` 完成后执行：

```shell
# 移除 OpenWrt feeds 自带的核心组件
rm -rf feeds/packages/net/{xray-core,v2ray-geodata,sing-box,chinadns-ng,dns2socks,hysteria,ipt2socks,microsocks,naiveproxy,shadowsocks-rust,shadowsocksr-libev,simple-obfs,tcping,v2ray-plugin,xray-plugin,geoview,shadow-tls}
git clone --branch main --single-branch https://github.com/Openwrt-Passwall/openwrt-passwall-packages package/passwall-packages

# 移除 OpenWrt feeds 自带的 LuCI 版本，并使用本仓库代码
rm -rf feeds/luci/applications/luci-app-passwall
git clone --branch main --single-branch https://github.com/MitaHill/openwrt-passwall-mitahill-version package/passwall-luci
```
