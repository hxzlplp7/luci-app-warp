#!/bin/sh
# One-shot installer for luci-app-warp.
# SPDX-License-Identifier: GPL-3.0-or-later

set -eu

REPO_RAW="${REPO_RAW:-https://raw.githubusercontent.com/hxzlplp7/luci-app-warp/main}"
USQUE_VERSION="${USQUE_VERSION:-3.0.0}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
	printf '%b\n' "${BLUE}==>${NC} $*"
}

ok() {
	printf '%b\n' "${GREEN}OK:${NC} $*"
}

warn() {
	printf '%b\n' "${YELLOW}WARN:${NC} $*"
}

die() {
	printf '%b\n' "${RED}ERROR:${NC} $*" >&2
	exit 1
}

download() {
	url="$1"
	dest="$2"

	if command -v curl >/dev/null 2>&1; then
		curl -fL --connect-timeout 15 --retry 2 "$url" -o "$dest"
	elif command -v wget >/dev/null 2>&1; then
		wget -O "$dest" "$url"
	else
		die "curl or wget is required"
	fi
}

check_system() {
	[ "$(id -u)" = "0" ] || die "run this installer as root"
	[ -f /etc/openwrt_release ] || die "this installer only supports OpenWrt"

	. /etc/openwrt_release
	ok "detected ${DISTRIB_DESCRIPTION:-OpenWrt}"
}

install_opkg_packages() {
	log "installing OpenWrt packages"
	if ! opkg update; then
		warn "opkg update reported errors; continuing with the package lists that are available"
	fi

	install_opkg_package luci-base
	install_opkg_package ca-bundle
	install_opkg_package jsonfilter
	install_opkg_package unzip
	install_opkg_package curl optional || \
		warn "curl was not installed; WARP+ license update and connection test commands may be unavailable"

	if [ ! -c /dev/net/tun ]; then
		install_opkg_package kmod-tun
	fi

	# Optional helper for SOCKS mode. NAT uses the system firewall backend
	# already present on the device: nftables on firewall4, iptables on firewall3.
	install_opkg_package microsocks optional || \
		warn "microsocks was not installed; SOCKS5 mode may be unavailable"
}

opkg_package_installed() {
	opkg status "$1" 2>/dev/null | grep -q "^Status: .* installed"
}

install_opkg_package() {
	pkg="$1"
	mode="${2:-required}"

	if opkg_package_installed "$pkg"; then
		return 0
	fi

	if opkg install "$pkg" >/dev/null; then
		return 0
	fi

	if [ "$mode" = "optional" ]; then
		return 1
	fi
	die "failed to install required package: $pkg"
}

usque_asset_arch() {
	opkg_arches="$(opkg print-architecture 2>/dev/null || true)"

	case "$(uname -m)" in
		x86_64)
			printf '%s\n' "linux_amd64"
			;;
		aarch64|arm64)
			printf '%s\n' "linux_arm64"
			;;
		armv7*|armv7l)
			printf '%s\n' "linux_armv7"
			;;
		armv6*|armv6l)
			printf '%s\n' "linux_armv6"
			;;
		armv5*|armv5l)
			printf '%s\n' "linux_armv5"
			;;
		mips)
			case "$opkg_arches" in
				*mipsel*|*mipsle*)
					return 1
					;;
			esac
			printf '%s\n' "linux_mips"
			;;
		*)
			return 1
			;;
	esac
}

install_usque() {
	if command -v usque >/dev/null 2>&1; then
		ok "usque is already installed"
		return
	fi

	if opkg install usque >/dev/null 2>&1; then
		ok "installed usque from opkg"
		return
	fi

	asset_arch="$(usque_asset_arch)" || die "no prebuilt usque binary for $(uname -m); build usque manually and install it as /usr/bin/usque"
	asset="usque_${USQUE_VERSION}_${asset_arch}.zip"
	url="https://github.com/Diniboy1123/usque/releases/download/v${USQUE_VERSION}/${asset}"
	tmpdir="/tmp/luci-app-warp-usque.$$"

	log "downloading usque ${USQUE_VERSION} (${asset_arch})"
	rm -rf "$tmpdir"
	mkdir -p "$tmpdir"
	download "$url" "$tmpdir/usque.zip"
	unzip -o "$tmpdir/usque.zip" -d "$tmpdir" >/dev/null

	usque_file="$(find "$tmpdir" -type f -name usque | head -n 1)"
	[ -n "$usque_file" ] || die "downloaded usque archive did not contain a usque binary"

	mkdir -p /usr/bin
	cp "$usque_file" /usr/bin/usque
	chmod 0755 /usr/bin/usque
	rm -rf "$tmpdir"
	ok "installed /usr/bin/usque"
}

install_app() {
	log "installing luci-app-warp files"

	mkdir -p /etc/warp
	mkdir -p /etc/config
	mkdir -p /etc/init.d
	mkdir -p /usr/bin
	mkdir -p /usr/share/luci/menu.d
	mkdir -p /usr/share/rpcd/acl.d
	mkdir -p /www/luci-static/resources/view/warp

	download "$REPO_RAW/root/usr/bin/warp-manager" /usr/bin/warp-manager
	download "$REPO_RAW/root/usr/bin/warp-update-china" /usr/bin/warp-update-china
	download "$REPO_RAW/root/usr/bin/warp-log" /usr/bin/warp-log
	download "$REPO_RAW/root/etc/init.d/warp" /etc/init.d/warp
	download "$REPO_RAW/root/etc/init.d/warp-cron" /etc/init.d/warp-cron

	if [ ! -f /etc/config/warp ]; then
		download "$REPO_RAW/root/etc/config/warp" /etc/config/warp
	else
		warn "kept existing /etc/config/warp"
	fi

	download "$REPO_RAW/root/usr/share/luci/menu.d/luci-app-warp.json" /usr/share/luci/menu.d/luci-app-warp.json
	download "$REPO_RAW/root/usr/share/rpcd/acl.d/luci-app-warp.json" /usr/share/rpcd/acl.d/luci-app-warp.json
	download "$REPO_RAW/htdocs/luci-static/resources/view/warp/status.js" /www/luci-static/resources/view/warp/status.js
	download "$REPO_RAW/htdocs/luci-static/resources/view/warp/settings.js" /www/luci-static/resources/view/warp/settings.js
	download "$REPO_RAW/htdocs/luci-static/resources/view/warp/log.js" /www/luci-static/resources/view/warp/log.js

	chmod 0755 /usr/bin/warp-manager /usr/bin/warp-update-china /usr/bin/warp-log
	chmod 0755 /etc/init.d/warp /etc/init.d/warp-cron

	/etc/init.d/warp enable >/dev/null 2>&1 || true
	rm -rf /tmp/luci-indexcache /tmp/luci-modulecache
	/etc/init.d/rpcd restart >/dev/null 2>&1 || true
	/etc/init.d/uhttpd restart >/dev/null 2>&1 || true

	ok "luci-app-warp files installed"
}

register_account() {
	[ -t 0 ] || {
		warn "skipping interactive registration because stdin is not a terminal"
		return
	}

	printf 'Register a WARP account now? [y/N] '
	read -r choice
	case "$choice" in
		y|Y|yes|YES)
			/usr/bin/warp-manager register
			;;
		*)
			warn "skipped registration; run 'warp-manager register' later"
			;;
	esac
}

main() {
	check_system
	install_opkg_packages
	install_usque
	install_app
	register_account

	printf '\n%b\n' "${GREEN}Installation complete.${NC}"
	printf '%s\n' "LuCI: Services -> Cloudflare WARP"
	printf '%s\n' "CLI : warp-manager register && /etc/init.d/warp start"
}

main "$@"
