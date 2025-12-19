-- Copyright (C) 2024
-- SPDX-License-Identifier: GPL-3.0-or-later

local m, s, o
local sys = require "luci.sys"
local uci = require "luci.model.uci".cursor()

m = Map("warp", translate("Cloudflare WARP"),
    translate("Cloudflare WARP 是一个免费的VPN服务，可以加密您的网络流量并提供更快、更安全的互联网访问。"))

-- 基本设置
s = m:section(TypedSection, "warp", translate("基本设置"))
s.anonymous = true
s.addremove = false

o = s:option(Flag, "enabled", translate("启用"))
o.rmempty = false
o.default = "0"

o = s:option(Value, "endpoint", translate("服务器地址"))
o.default = "engage.cloudflareclient.com:2408"
o.rmempty = false
o.description = translate("WARP 服务器端点地址和端口")

o = s:option(Value, "mtu", translate("MTU"))
o.datatype = "range(1280,1500)"
o.default = "1280"
o.rmempty = false

o = s:option(Value, "dns", translate("DNS 服务器"))
o.default = "1.1.1.1"
o.rmempty = false
o.description = translate("使用的DNS服务器地址")

o = s:option(Flag, "ipv6", translate("启用 IPv6"))
o.rmempty = false
o.default = "1"
o.description = translate("启用IPv6支持")

-- 代理设置
s = m:section(TypedSection, "warp", translate("代理设置"))
s.anonymous = true
s.addremove = false

o = s:option(Flag, "global_proxy", translate("全局代理"))
o.rmempty = false
o.default = "1"
o.description = translate("启用后，所有流量都将通过WARP。禁用则仅代理指定的目标。")

o = s:option(Flag, "bypass_china", translate("绕过中国大陆IP"))
o.rmempty = false
o.default = "0"
o.description = translate("启用后，中国大陆IP将不经过WARP直连")

-- SOCKS代理设置
s = m:section(TypedSection, "warp", translate("SOCKS5 代理"))
s.anonymous = true
s.addremove = false

o = s:option(Flag, "socks_enabled", translate("启用 SOCKS5 代理"))
o.rmempty = false
o.default = "1"
o.description = translate("在本地开启 SOCKS5 代理端口，供其他设备或应用使用")

o = s:option(Value, "socks_port", translate("SOCKS5 端口"))
o.datatype = "port"
o.default = "1080"
o.rmempty = false
o.description = translate("SOCKS5 代理监听端口")

-- 账户信息（只读）
s = m:section(TypedSection, "warp", translate("账户信息"))
s.anonymous = true
s.addremove = false

o = s:option(DummyValue, "address_v4", translate("IPv4 地址"))
o.template = "cbi/dvalue"
function o.cfgvalue(self, section)
    return uci:get("warp", "config", "address_v4") or translate("未配置")
end

o = s:option(DummyValue, "address_v6", translate("IPv6 地址"))
o.template = "cbi/dvalue"
function o.cfgvalue(self, section)
    return uci:get("warp", "config", "address_v6") or translate("未配置")
end

o = s:option(Value, "license_key", translate("WARP+ License Key"))
o.password = true
o.rmempty = true
o.description = translate("如果您有WARP+ License Key，可以在此输入以升级到WARP+")

-- 高级设置
s = m:section(TypedSection, "warp", translate("高级设置"))
s.anonymous = true
s.addremove = false

o = s:option(Value, "private_key", translate("私钥"))
o.password = true
o.rmempty = true
o.description = translate("WireGuard 私钥（自动生成，通常不需要手动修改）")

o = s:option(Value, "public_key", translate("公钥"))
o.rmempty = true
o.readonly = true
o.description = translate("WireGuard 公钥")

o = s:option(Value, "reserved", translate("Reserved 字节"))
o.rmempty = true
o.description = translate("WARP Reserved 字节（用于识别客户端）")

return m
