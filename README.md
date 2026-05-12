# PassWall MitaHill Version

<p align="center">
  <a href="https://github.com/MitaHill/openwrt-passwall-mitahill-version/actions/workflows/Auto%20compile%20with%20openwrt%20sdk.yml"><img src="https://img.shields.io/github/actions/workflow/status/MitaHill/openwrt-passwall-mitahill-version/Auto%20compile%20with%20openwrt%20sdk.yml?branch=main&style=for-the-badge&label=Build" alt="Build Status"></a>
  <a href="https://github.com/MitaHill/openwrt-passwall-mitahill-version/releases"><img src="https://img.shields.io/github/v/release/MitaHill/openwrt-passwall-mitahill-version?style=for-the-badge&label=Release" alt="Release"></a>
  <a href="https://github.com/Openwrt-Passwall/openwrt-passwall"><img src="https://img.shields.io/badge/Upstream-Openwrt--Passwall-blue?style=for-the-badge" alt="Upstream"></a>
  <img src="https://img.shields.io/badge/OpenWrt-LuCI-00B5E2?style=for-the-badge" alt="OpenWrt LuCI">
</p>

<p align="center">
  一个面向自用与验证的 PassWall 修复分支，跟随上游更新，并对实际使用中遇到的细节问题做最小化补全。
</p>

## 项目定位

本仓库基于 [Openwrt-Passwall/openwrt-passwall](https://github.com/Openwrt-Passwall/openwrt-passwall)，用于跟进上游代码，同时修复或验证一些尚未合入上游、但会影响日常使用体验的问题。

重点原则：

- 尽量保持上游结构，不做大规模重写。
- 修复真实使用中的稳定性、分流、测速和编译细节问题。
- 每次改动尽量保持最小范围，方便回溯与继续同步上游。

## 当前关注

- Sing-box URLTest 与前置代理链路的分流一致性。
- PassWall 运行状态与节点列表测速的准确性。
- OpenWrt / ImmortalWrt SDK 云端编译兼容性。
- IPv6 TProxy 相关规则更新的稳定性。

## 构建

本仓库通过 GitHub Actions 使用 OpenWrt SDK 自动编译 LuCI 包。Release 版本号按编译日期生成，格式为：

```text
yyyy.mm.dd
```

构建产物请查看 [Releases](https://github.com/MitaHill/openwrt-passwall-mitahill-version/releases)。

## 说明

这是一个修复与验证分支，不替代 PassWall 上游项目。通用功能、协议支持和长期维护仍应优先关注上游仓库。
