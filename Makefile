# Copyright (C) 2024
# SPDX-License-Identifier: GPL-3.0-or-later

include $(TOPDIR)/rules.mk

LUCI_TITLE:=LuCI support for Cloudflare WARP
LUCI_DESCRIPTION:=LuCI interface for managing Cloudflare WARP via WireGuard
LUCI_DEPENDS:=+wireguard-tools +luci-proto-wireguard +curl +jsonfilter +kmod-wireguard
LUCI_PKGARCH:=all

PKG_NAME:=luci-app-warp
PKG_VERSION:=1.0.0
PKG_RELEASE:=1

PKG_MAINTAINER:=Your Name <your@email.com>
PKG_LICENSE:=GPL-3.0-or-later

include $(TOPDIR)/feeds/luci/luci.mk

# call BuildPackage - OpenWrt buildance
