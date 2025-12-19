# Copyright (C) 2024
# SPDX-License-Identifier: GPL-3.0-or-later

include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-warp
PKG_VERSION:=1.0.2
PKG_RELEASE:=1

PKG_MAINTAINER:=hxzlplp7
PKG_LICENSE:=GPL-3.0-or-later

include $(INCLUDE_DIR)/package.mk

define Package/$(PKG_NAME)
  SECTION:=luci
  CATEGORY:=LuCI
  SUBMENU:=3. Applications
  TITLE:=LuCI support for Cloudflare WARP
  DEPENDS:=+luci-base +wireguard-tools +luci-proto-wireguard +curl +jsonfilter
  PKGARCH:=all
endef

define Package/$(PKG_NAME)/description
  LuCI interface for managing Cloudflare WARP via WireGuard with global proxy support.
  Features include auto registration, global traffic proxy, China IP bypass, and WARP+ license upgrade.
endef

define Package/$(PKG_NAME)/conffiles
/etc/config/warp
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
endef

define Build/Compile
endef

define Package/$(PKG_NAME)/install
	# Install UCI config
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_CONF) $(CURDIR)/root/etc/config/warp $(1)/etc/config/warp
	
	# Install init scripts
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) $(CURDIR)/root/etc/init.d/warp $(1)/etc/init.d/warp
	$(INSTALL_BIN) $(CURDIR)/root/etc/init.d/warp-cron $(1)/etc/init.d/warp-cron
	
	# Install binary scripts
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) $(CURDIR)/root/usr/bin/warp-manager $(1)/usr/bin/warp-manager
	$(INSTALL_BIN) $(CURDIR)/root/usr/bin/warp-update-china $(1)/usr/bin/warp-update-china
	
	# Install LuCI controller
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/controller
	$(INSTALL_DATA) $(CURDIR)/luasrc/controller/warp.lua $(1)/usr/lib/lua/luci/controller/warp.lua
	
	# Install LuCI model
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/model/cbi/warp
	$(INSTALL_DATA) $(CURDIR)/luasrc/model/cbi/warp/settings.lua $(1)/usr/lib/lua/luci/model/cbi/warp/settings.lua
	
	# Install LuCI views
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/view/warp
	$(INSTALL_DATA) $(CURDIR)/luasrc/view/warp/status.htm $(1)/usr/lib/lua/luci/view/warp/status.htm
	$(INSTALL_DATA) $(CURDIR)/luasrc/view/warp/log.htm $(1)/usr/lib/lua/luci/view/warp/log.htm
	
	# Install ACL
	$(INSTALL_DIR) $(1)/usr/share/rpcd/acl.d
	$(INSTALL_DATA) $(CURDIR)/root/usr/share/rpcd/acl.d/luci-app-warp.json $(1)/usr/share/rpcd/acl.d/luci-app-warp.json
	
	# Install menu
	$(INSTALL_DIR) $(1)/usr/share/luci/menu.d
	$(INSTALL_DATA) $(CURDIR)/root/usr/share/luci/menu.d/luci-app-warp.json $(1)/usr/share/luci/menu.d/luci-app-warp.json
endef

define Package/$(PKG_NAME)/postinst
#!/bin/sh
[ -n "$${IPKG_INSTROOT}" ] || {
	/etc/init.d/warp enable 2>/dev/null
	/etc/init.d/rpcd restart 2>/dev/null
}
exit 0
endef

define Package/$(PKG_NAME)/prerm
#!/bin/sh
[ -n "$${IPKG_INSTROOT}" ] || {
	/etc/init.d/warp stop 2>/dev/null
	/etc/init.d/warp disable 2>/dev/null
}
exit 0
endef

$(eval $(call BuildPackage,$(PKG_NAME)))
