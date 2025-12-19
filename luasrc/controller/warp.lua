-- Copyright (C) 2024
-- SPDX-License-Identifier: GPL-3.0-or-later

module("luci.controller.warp", package.seeall)

function index()
    if not nixio.fs.access("/etc/config/warp") then
        return
    end
    
    local page
    
    page = entry({"admin", "services", "warp"}, firstchild(), _("Cloudflare WARP"), 80)
    page.dependent = false
    page.acl_depends = { "luci-app-warp" }
    
    entry({"admin", "services", "warp", "settings"}, cbi("warp/settings"), _("设置"), 10).leaf = true
    entry({"admin", "services", "warp", "status"}, template("warp/status"), _("状态"), 20).leaf = true
    entry({"admin", "services", "warp", "log"}, template("warp/log"), _("日志"), 30).leaf = true
    
    -- API endpoints
    entry({"admin", "services", "warp", "api", "status"}, call("action_status")).leaf = true
    entry({"admin", "services", "warp", "api", "register"}, post("action_register")).leaf = true
    entry({"admin", "services", "warp", "api", "test"}, call("action_test")).leaf = true
    entry({"admin", "services", "warp", "api", "start"}, post("action_start")).leaf = true
    entry({"admin", "services", "warp", "api", "stop"}, post("action_stop")).leaf = true
    entry({"admin", "services", "warp", "api", "restart"}, post("action_restart")).leaf = true
    entry({"admin", "services", "warp", "api", "license"}, post("action_license")).leaf = true
    entry({"admin", "services", "warp", "api", "reset"}, post("action_reset")).leaf = true
end

function action_status()
    local http = require "luci.http"
    local sys = require "luci.sys"
    local uci = require "luci.model.uci".cursor()
    local jsonc = require "luci.jsonc"
    
    local socks_port = uci:get("warp", "config", "socks_port") or "1080"
    local socks_enabled = uci:get("warp", "config", "socks_enabled") or "1"
    
    local status = {
        enabled = uci:get("warp", "config", "enabled") == "1",
        running = false,
        connected = false,
        interface_exists = false,
        account_registered = false,
        warp_status = "unknown",
        exit_ip = "",
        location = "",
        handshake = "",
        tx = "",
        rx = "",
        address_v4 = uci:get("warp", "config", "address_v4") or "",
        address_v6 = uci:get("warp", "config", "address_v6") or "",
        socks_port = socks_port,
        socks_enabled = socks_enabled == "1",
        socks_running = false
    }
    
    -- 检查接口是否存在
    local if_exists = sys.call("ip link show warp >/dev/null 2>&1")
    status.interface_exists = (if_exists == 0)
    
    -- 检查账户是否注册
    local account_exists = nixio.fs.access("/etc/warp/account.json")
    status.account_registered = account_exists
    
    -- 检查SOCKS代理是否运行
    local socks_check = sys.call("netstat -tln 2>/dev/null | grep -q ':" .. socks_port .. " '")
    status.socks_running = (socks_check == 0)
    
    if status.interface_exists then
        status.running = true
        
        -- 获取WireGuard状态
        local wg_output = sys.exec("wg show warp 2>/dev/null")
        if wg_output and wg_output ~= "" then
            local handshake = wg_output:match("latest handshake: ([^\n]+)")
            local transfer = wg_output:match("transfer: ([^\n]+)")
            
            if handshake then
                status.connected = true
                status.handshake = handshake
            end
            
            if transfer then
                local tx, rx = transfer:match("([%d%.]+%s*%w+) received, ([%d%.]+%s*%w+) sent")
                if tx and rx then
                    status.rx = tx
                    status.tx = rx
                end
            end
        end
    end
    
    http.prepare_content("application/json")
    http.write_json(status)
end

function action_register()
    local http = require "luci.http"
    local sys = require "luci.sys"
    
    local result = sys.exec("/usr/bin/warp-manager register 2>&1")
    local success = result:find("注册成功") ~= nil
    
    http.prepare_content("application/json")
    http.write_json({
        success = success,
        message = result
    })
end

function action_test()
    local http = require "luci.http"
    local sys = require "luci.sys"
    local uci = require "luci.model.uci".cursor()
    
    local result = {
        success = false,
        warp_status = "unknown",
        exit_ip = "",
        location = ""
    }
    
    -- 获取SOCKS端口
    local socks_port = uci:get("warp", "config", "socks_port") or "1080"
    
    -- 先尝试通过SOCKS代理测试
    local trace = sys.exec("curl -s --socks5 127.0.0.1:" .. socks_port .. " --max-time 10 https://www.cloudflare.com/cdn-cgi/trace 2>/dev/null")
    
    -- 如果SOCKS失败，尝试直接通过warp接口测试
    if not trace or trace == "" then
        trace = sys.exec("curl -s --max-time 10 https://www.cloudflare.com/cdn-cgi/trace 2>/dev/null")
    end
    
    if trace and trace ~= "" then
        result.success = true
        result.warp_status = trace:match("warp=([^\n]+)") or "unknown"
        result.exit_ip = trace:match("ip=([^\n]+)") or ""
        result.location = trace:match("loc=([^\n]+)") or ""
    end
    
    http.prepare_content("application/json")
    http.write_json(result)
end

function action_start()
    local http = require "luci.http"
    local sys = require "luci.sys"
    local uci = require "luci.model.uci".cursor()
    
    uci:set("warp", "config", "enabled", "1")
    uci:commit("warp")
    
    sys.call("/etc/init.d/warp start >/dev/null 2>&1")
    
    http.prepare_content("application/json")
    http.write_json({ success = true })
end

function action_stop()
    local http = require "luci.http"
    local sys = require "luci.sys"
    local uci = require "luci.model.uci".cursor()
    
    uci:set("warp", "config", "enabled", "0")
    uci:commit("warp")
    
    sys.call("/etc/init.d/warp stop >/dev/null 2>&1")
    
    http.prepare_content("application/json")
    http.write_json({ success = true })
end

function action_restart()
    local http = require "luci.http"
    local sys = require "luci.sys"
    
    sys.call("/etc/init.d/warp restart >/dev/null 2>&1")
    
    http.prepare_content("application/json")
    http.write_json({ success = true })
end

function action_license()
    local http = require "luci.http"
    local sys = require "luci.sys"
    
    local license_key = http.formvalue("license_key")
    
    if not license_key or license_key == "" then
        http.prepare_content("application/json")
        http.write_json({ success = false, message = "请输入License Key" })
        return
    end
    
    local result = sys.exec("/usr/bin/warp-manager license '" .. license_key .. "' 2>&1")
    local success = result:find("成功") ~= nil
    
    http.prepare_content("application/json")
    http.write_json({
        success = success,
        message = result
    })
end

function action_reset()
    local http = require "luci.http"
    local sys = require "luci.sys"
    
    sys.call("/usr/bin/warp-manager reset >/dev/null 2>&1")
    
    http.prepare_content("application/json")
    http.write_json({ success = true })
end
