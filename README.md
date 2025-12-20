# luci-app-warp

[![License](https://img.shields.io/badge/license-GPL--3.0-blue.svg)](LICENSE)
[![OpenWrt](https://img.shields.io/badge/OpenWrt-21.02%2B-green.svg)](https://openwrt.org/)

OpenWrt 平台的 Cloudflare WARP LuCI 管理界面，支持全局流量接管。

![状态页面](docs/screenshot-status.png)

## ✨ 功能特性

- 🚀 **一键安装** - 自动安装所有依赖并配置
- 🔐 **自动注册** - 无需手动获取配置文件，自动注册WARP账户
- 🌍 **全局代理** - 支持全局流量接管模式
- 🇨🇳 **绕过中国IP** - 可选择性绕过中国大陆IP，优化国内访问
- 📊 **状态监控** - 实时显示连接状态、流量统计
- 🔑 **WARP+升级** - 支持应用License Key升级到WARP+
- 🎨 **现代UI** - 美观的LuCI管理界面

## 📦 依赖

- OpenWrt 21.02 或更高版本
- WireGuard 支持 (`kmod-wireguard`, `wireguard-tools`)
- `luci-proto-wireguard`
- `curl`
- `jsonfilter`

## 🚀 快速安装

### 方法一：一键安装脚本（推荐）

```bash
wget -O- https://raw.githubusercontent.com/hxzlplp7/luci-app-warp/main/install.sh | sh
```

或者：

```bash
curl -fsSL https://raw.githubusercontent.com/hxzlplp7/luci-app-warp/main/install.sh | sh
```

### 方法二：手动安装

1. **安装依赖**

```bash
opkg update
opkg install wireguard-tools kmod-wireguard luci-proto-wireguard curl jsonfilter
```

2. **下载并安装**

```bash
# 克隆仓库
git clone https://github.com/hxzlplp7/luci-app-warp.git /tmp/luci-app-warp

# 复制文件
cp -r /tmp/luci-app-warp/root/* /
cp -r /tmp/luci-app-warp/luasrc/* /usr/lib/lua/luci/

# 设置权限
chmod +x /usr/bin/warp-manager
chmod +x /etc/init.d/warp

# 启用服务
/etc/init.d/warp enable
```

### 方法三：从源码编译

```bash
# 进入OpenWrt源码目录
cd openwrt

# 添加软件源
echo "src-git warp https://github.com/your-repo/luci-app-warp.git" >> feeds.conf.default

# 更新feeds
./scripts/feeds update warp
./scripts/feeds install luci-app-warp

# 编译
make package/luci-app-warp/compile V=s
```

## 📖 使用说明

### Web界面（LuCI）

1. 打开路由器管理界面
2. 导航到 **服务 → Cloudflare WARP**
3. 在 **状态** 页面点击 **注册账户**
4. 注册成功后点击 **启动** 开始使用

### 命令行

```bash
# 注册账户
warp-manager register

# 查看状态
warp-manager status

# 测试连接
warp-manager test

# 应用License Key升级到WARP+
warp-manager license aBcD1234-eFgH5678-iJkL9012

# 导出WireGuard配置
warp-manager export

# 重置账户
warp-manager reset
```

### 服务管理

```bash
# 启动服务
/etc/init.d/warp start

# 停止服务
/etc/init.d/warp stop

# 重启服务
/etc/init.d/warp restart

# 查看服务状态
/etc/init.d/warp status
```

## ⚙️ 配置选项

| 选项 | 说明 | 默认值 |
|------|------|--------|
| `enabled` | 启用WARP | `0` |
| `endpoint` | WARP服务器地址 | `engage.cloudflareclient.com:2408` |
| `mtu` | MTU值 | `1280` |
| `dns` | DNS服务器 | `1.1.1.1` |
| `ipv6` | 启用IPv6 | `1` |
| `global_proxy` | 全局代理模式 | `1` |
| `bypass_china` | 绕过中国大陆IP | `0` |

### 配置文件

配置文件位于 `/etc/config/warp`：

```
config warp 'config'
    option enabled '1'
    option endpoint 'engage.cloudflareclient.com:2408'
    option mtu '1280'
    option dns '1.1.1.1'
    option ipv6 '1'
    option global_proxy '1'
    option bypass_china '0'
    option private_key 'YOUR_PRIVATE_KEY'
    option address_v4 '172.16.0.x'
    option address_v6 '2606:4700:xxx'
```

## 🌐 全局流量接管

启用全局代理后，所有来自LAN的流量都将通过WARP隧道：

1. 在设置中开启 **全局代理**
2. 防火墙会自动配置 LAN → WARP 的转发规则
3. 所有设备无需额外配置即可使用

### 绕过中国大陆IP

如果需要国内网站直连：

1. 在设置中开启 **绕过中国大陆IP**
2. 系统会自动下载并应用中国IP列表
3. 访问国内网站时走直连，国外网站走WARP

## 🔧 Endpoint 优选

如果连接不稳定，可以尝试更换Endpoint：

```bash
# 常用Endpoint
engage.cloudflareclient.com:2408
engage.cloudflareclient.com:500
engage.cloudflareclient.com:854
engage.cloudflareclient.com:4500

# 或使用优选IP
162.159.192.1:2408
162.159.193.1:2408
162.159.195.1:2408
```

## ❓ 常见问题

### Q: 注册失败怎么办？

A: 确保路由器能正常访问外网，检查DNS设置。如果仍然失败，可能是Cloudflare API暂时不可用，稍后再试。

### Q: 连接后无法上网？

A: 检查以下几点：
1. WireGuard内核模块是否加载：`lsmod | grep wireguard`
2. 接口是否正确创建：`ip link show warp`
3. 防火墙规则是否正确：`iptables -L -n | grep warp`

### Q: 如何升级到WARP+？

A: 在LuCI界面点击"应用License"，输入从WARP+订阅获取的License Key。

### Q: 如何获取License Key？

A: 
- 购买WARP+订阅
- 通过WARP推荐计划获取免费流量
- 使用第三方生成器（不保证可用性）

## 📝 更新日志

### v1.0.0 (2024-12-20)
- 🎉 首次发布
- ✨ 支持自动注册WARP账户
- ✨ 支持全局流量接管
- ✨ 支持绕过中国大陆IP
- ✨ 支持WARP+ License升级
- ✨ LuCI管理界面

## 🙏 致谢

- [Cloudflare WARP](https://1.1.1.1/) - 免费的VPN服务
- [wgcf](https://github.com/ViRb3/wgcf) - WARP配置生成工具
- [OpenWrt](https://openwrt.org/) - 开源路由器操作系统

## 📄 许可证

本项目采用 [GPL-3.0](LICENSE) 许可证。

---

如有问题或建议，欢迎提交 [Issue](https://github.com/your-repo/luci-app-warp/issues)！
