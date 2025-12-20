# Copyright (C) 2024
# SPDX-License-Identifier: GPL-3.0-or-later

include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-warp
PKG_VERSION:=1.2.1
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
  Features include auto registration, global traffic proxy, China IP bypass, 
  SOCKS5 proxy, pre-proxy support, and WARP+ license upgrade.
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
	
	# Install LuCI JS views (new style)
	$(INSTALL_DIR) $(1)/www/luci-static/resources/view/warp
	$(INSTALL_DATA) $(CURDIR)/htdocs/luci-static/resources/view/warp/status.js $(1)/www/luci-static/resources/view/warp/status.js
	$(INSTALL_DATA) $(CURDIR)/htdocs/luci-static/resources/view/warp/settings.js $(1)/www/luci-static/resources/view/warp/settings.js
	$(INSTALL_DATA) $(CURDIR)/htdocs/luci-static/resources/view/warp/log.js $(1)/www/luci-static/resources/view/warp/log.js
	
	# Install ACL
	$(INSTALL_DIR) $(1)/usr/share/rpcd/acl.d
	$(INSTALL_DATA) $(CURDIR)/root/usr/share/rpcd/acl.d/luci-app-warp.json $(1)/usr/share/rpcd/acl.d/luci-app-warp.json
	
	# Install menu
	$(INSTALL_DIR) $(1)/usr/share/luci/menu.d
	$(INSTALL_DATA) $(CURDIR)/root/usr/share/luci/menu.d/luci-app-warp.json $(1)/usr/share/luci/menu.d/luci-app-warp.json
	
	# Create warp data directory
	$(INSTALL_DIR) $(1)/etc/warp
endef

define Package/$(PKG_NAME)/postinst
#!/bin/sh
[ -n "$${IPKG_INSTROOT}" ] || {
	/etc/init.d/warp enable 2>/dev/null
	/etc/init.d/rpcd restart 2>/dev/null
	rm -rf /tmp/luci-indexcache /tmp/luci-modulecache
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
