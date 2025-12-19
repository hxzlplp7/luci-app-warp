#!/bin/sh
# 一键安装脚本
# Copyright (C) 2024

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}"
echo "╔═══════════════════════════════════════════╗"
echo "║     Cloudflare WARP for OpenWrt           ║"
echo "║         一键安装脚本                       ║"
echo "╚═══════════════════════════════════════════╝"
echo -e "${NC}"

# 检查是否为root
[ "$(id -u)" != "0" ] && {
    echo -e "${RED}错误: 请使用root权限运行此脚本${NC}"
    exit 1
}

# 检查系统
check_system() {
    if [ ! -f /etc/openwrt_release ]; then
        echo -e "${RED}错误: 此脚本仅支持OpenWrt系统${NC}"
        exit 1
    fi
    
    . /etc/openwrt_release
    echo -e "${GREEN}检测到系统: ${DISTRIB_DESCRIPTION}${NC}"
}

# 安装依赖
install_deps() {
    echo -e "${BLUE}正在安装依赖...${NC}"
    
    opkg update
    
    # 安装WireGuard
    opkg install wireguard-tools kmod-wireguard luci-proto-wireguard
    
    # 安装其他依赖
    opkg install curl jsonfilter
    
    echo -e "${GREEN}依赖安装完成${NC}"
}

# 安装应用
install_app() {
    echo -e "${BLUE}正在安装 luci-app-warp...${NC}"
    
    # 创建目录
    mkdir -p /etc/warp
    mkdir -p /usr/share/luci/menu.d
    mkdir -p /usr/share/rpcd/acl.d
    
    # 复制文件（这里需要根据实际情况修改）
    # 假设从GitHub下载
    REPO_URL="https://raw.githubusercontent.com/your-repo/luci-app-warp/main"
    
    # 下载核心脚本
    curl -sL "${REPO_URL}/root/usr/bin/warp-manager" -o /usr/bin/warp-manager
    chmod +x /usr/bin/warp-manager
    
    # 下载init脚本
    curl -sL "${REPO_URL}/root/etc/init.d/warp" -o /etc/init.d/warp
    chmod +x /etc/init.d/warp
    
    # 下载配置文件
    [ ! -f /etc/config/warp ] && \
        curl -sL "${REPO_URL}/root/etc/config/warp" -o /etc/config/warp
    
    # 启用服务
    /etc/init.d/warp enable
    
    echo -e "${GREEN}应用安装完成${NC}"
}

# 注册账户
register_account() {
    echo ""
    read -p "是否现在注册WARP账户? [Y/n] " choice
    case "$choice" in
        [Nn]*)
            echo "跳过注册，您可以稍后在LuCI界面中注册"
            ;;
        *)
            /usr/bin/warp-manager register
            ;;
    esac
}

# 主流程
main() {
    check_system
    install_deps
    install_app
    register_account
    
    echo ""
    echo -e "${GREEN}═══════════════════════════════════════════${NC}"
    echo -e "${GREEN}安装完成!${NC}"
    echo ""
    echo "请访问 LuCI 界面:"
    echo "  服务 -> Cloudflare WARP"
    echo ""
    echo "或使用命令行:"
    echo "  warp-manager status    # 查看状态"
    echo "  warp-manager register  # 注册账户"
    echo "  warp-manager test      # 测试连接"
    echo ""
    echo "启动服务:"
    echo "  /etc/init.d/warp start"
    echo -e "${GREEN}═══════════════════════════════════════════${NC}"
}

main
