# Copyright (C) 2024
# SPDX-License-Identifier: GPL-3.0-or-later

include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-warp
PKG_VERSION:=1.0.0
PKG_RELEASE:=1

PKG_MAINTAINER:=hxzlplp7
PKG_LICENSE:=GPL-3.0-or-later

LUCI_TITLE:=LuCI support for Cloudflare WARP
LUCI_DESCRIPTION:=LuCI interface for managing Cloudflare WARP via WireGuard with global proxy support
LUCI_DEPENDS:=+wireguard-tools +luci-proto-wireguard +curl +jsonfilter +kmod-wireguard
LUCI_PKGARCH:=all

define Package/$(PKG_NAME)
  SECTION:=luci
  CATEGORY:=LuCI
  SUBMENU:=3. Applications
  TITLE:=$(LUCI_TITLE)
  DEPENDS:=$(LUCI_DEPENDS)
  PKGARCH:=all
endef

define Package/$(PKG_NAME)/description
$(LUCI_DESCRIPTION)
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
endef

define Build/Compile
endef

define Package/$(PKG_NAME)/conffiles
/etc/config/warp
endef

define Package/$(PKG_NAME)/install
	# Install UCI config
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_CONF) ./root/etc/config/warp $(1)/etc/config/warp
	
	# Install init scripts
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./root/etc/init.d/warp $(1)/etc/init.d/warp
	$(INSTALL_BIN) ./root/etc/init.d/warp-cron $(1)/etc/init.d/warp-cron
	
	# Install binary scripts
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) ./root/usr/bin/warp-manager $(1)/usr/bin/warp-manager
	$(INSTALL_BIN) ./root/usr/bin/warp-update-china $(1)/usr/bin/warp-update-china
	
	# Install LuCI controller
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/controller
	$(INSTALL_DATA) ./luasrc/controller/warp.lua $(1)/usr/lib/lua/luci/controller/warp.lua
	
	# Install LuCI model
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/model/cbi/warp
	$(INSTALL_DATA) ./luasrc/model/cbi/warp/settings.lua $(1)/usr/lib/lua/luci/model/cbi/warp/settings.lua
	
	# Install LuCI views
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/view/warp
	$(INSTALL_DATA) ./luasrc/view/warp/status.htm $(1)/usr/lib/lua/luci/view/warp/status.htm
	$(INSTALL_DATA) ./luasrc/view/warp/log.htm $(1)/usr/lib/lua/luci/view/warp/log.htm
	
	# Install ACL
	$(INSTALL_DIR) $(1)/usr/share/rpcd/acl.d
	$(INSTALL_DATA) ./root/usr/share/rpcd/acl.d/luci-app-warp.json $(1)/usr/share/rpcd/acl.d/luci-app-warp.json
	
	# Install menu
	$(INSTALL_DIR) $(1)/usr/share/luci/menu.d
	$(INSTALL_DATA) ./root/usr/share/luci/menu.d/luci-app-warp.json $(1)/usr/share/luci/menu.d/luci-app-warp.json
	
	# Install translations
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/i18n
	po2lmo ./po/zh_Hans/warp.po $(1)/usr/lib/lua/luci/i18n/warp.zh-cn.lmo 2>/dev/null || true
endef

define Package/$(PKG_NAME)/postinst
#!/bin/sh
[ -n "$$IPKG_INSTROOT" ] || {
	/etc/init.d/warp enable
	/etc/init.d/rpcd restart
}
exit 0
endef

define Package/$(PKG_NAME)/prerm
#!/bin/sh
[ -n "$$IPKG_INSTROOT" ] || {
	/etc/init.d/warp stop
	/etc/init.d/warp disable
}
exit 0
endef

$(eval $(call BuildPackage,$(PKG_NAME)))
