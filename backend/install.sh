#!/bin/bash

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

# 检查是否为root用户
if [[ $EUID -ne 0 ]]; then
    log_error "此脚本必须使用root权限运行"
fi

# 检查系统
check_system() {
    if [ -f /etc/debian_version ]; then
        OS="debian"
        source /etc/os-release
        VERSION_ID=$VERSION_ID
        log_info "检测到系统为: Debian $VERSION_ID"
        if [ "$VERSION_ID" -lt 8 ]; then
            log_error "系统版本过低，需要Debian 8+"
        fi
    else
        log_error "不支持的系统，本脚本仅支持Debian系统"
    fi
}

# 检查硬件要求
check_hardware() {
    local cpu_cores=$(grep -c ^processor /proc/cpuinfo)
    local total_mem=$(free -m | awk '/^Mem:/{print $2}')
    local free_disk=$(df -h / | awk 'NR==2 {print $4}' | sed 's/G//')
    
    log_info "检测到CPU核心数: $cpu_cores"
    log_info "检测到内存大小: $total_mem MB"
    log_info "检测到可用磁盘空间: $free_disk GB"
    
    if [ $cpu_cores -lt 2 ]; then
        log_warn "推荐至少2核CPU，当前为$cpu_cores核"
    fi
    
    if [ $total_mem -lt 2048 ]; then
        log_warn "推荐至少2GB内存，当前为$total_mem MB"
    fi
    
    if [ ${free_disk%.*} -lt 20 ]; then
        log_warn "推荐至少20GB可用磁盘空间，当前为$free_disk GB"
    fi
}

# 检查虚拟化支持
check_virtualization() {
    if grep -E 'vmx|svm' /proc/cpuinfo > /dev/null; then
        log_info "检测到CPU支持虚拟化"
    else
        log_warn "CPU可能不支持硬件虚拟化，将使用QEMU软件模拟"
    fi
    
    if lsmod | grep -i kvm > /dev/null; then
        log_info "检测到KVM模块已加载"
    else
        log_warn "KVM模块未加载，可能无法使用KVM加速"
    fi
}

# 检查网络环境
check_network() {
    local ip_info=$(ip -4 addr show | grep inet | grep -v "127.0.0.1")
    local ipv6_info=$(ip -6 addr show | grep inet6 | grep -v "::1" | grep -v "fe80")
    
    log_info "网络信息:"
    echo "$ip_info"
    
    if [ -n "$ipv6_info" ]; then
        log_info "检测到IPv6网络:"
        echo "$ipv6_info"
    else
        log_warn "未检测到IPv6网络"
    fi
}

# 创建虚拟内存
create_swap() {
    read -p "是否创建SWAP虚拟内存? [y/N]: " create_swap_choice
    if [[ "$create_swap_choice" =~ ^[Yy]$ ]]; then
        read -p "请输入SWAP大小(MB): " swap_size
        log_info "创建${swap_size}MB SWAP..."
        
        # 检查是否已存在swap
        if grep -q "swap" /etc/fstab; then
            log_warn "检测到已存在SWAP配置，跳过创建"
            return
        fi
        
        # 创建swap文件
        dd if=/dev/zero of=/swapfile bs=1M count=$swap_size
        chmod 600 /swapfile
        mkswap /swapfile
        swapon /swapfile
        echo '/swapfile none swap sw 0 0' >> /etc/fstab
        log_info "SWAP创建完成"
    fi
}

# 安装PVE
install_pve() {
    log_info "开始安装PVE..."
    
    # 强制使用国外官方源
    use_china_mirrors=false
    log_info "使用官方源..."
    
    # 更新系统
    log_info "更新系统..."
    apt-get update && apt-get upgrade -y
    
    # 安装必要工具
    log_info "安装必要工具..."
    apt-get install -y curl wget gnupg
    
    # 配置PVE源
    log_info "配置PVE源..."
    if [ "$use_china_mirrors" = true ]; then
        echo "deb https://mirrors.tuna.tsinghua.edu.cn/proxmox/debian/pve bullseye pve-no-subscription" > /etc/apt/sources.list.d/pve-install-repo.list
    else
        echo "deb http://download.proxmox.com/debian/pve bullseye pve-no-subscription" > /etc/apt/sources.list.d/pve-install-repo.list
    fi
    
    wget -q -O- "http://download.proxmox.com/debian/proxmox-ve-release-6.x.gpg" | apt-key add -
    apt-get update
    
    # 安装PVE
    log_info "安装PVE..."
    DEBIAN_FRONTEND=noninteractive apt-get install -y proxmox-ve postfix open-iscsi
    
    # 删除企业订阅提示
    log_info "移除订阅提示..."
    sed -i.bak "s/data.status !== 'Active'/false/g" /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js
    
    # 配置网络
    log_info "配置网络..."
    cp /etc/network/interfaces /etc/network/interfaces.bak
    
    # 获取主网卡名称
    main_interface=$(ip route | grep default | awk '{print $5}')
    
    # 检测IP配置方式
    if grep -q "dhcp" /etc/network/interfaces; then
        log_info "检测到DHCP配置，转换为静态IP配置..."
        ip_addr=$(ip -4 addr show $main_interface | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
        gateway=$(ip route | grep default | awk '{print $3}')
        prefix=$(ip -4 addr show $main_interface | grep -oP '(?<=inet\s)\d+(\.\d+){3}/\K\d+')
        
        cat > /etc/network/interfaces <<EOF
auto lo
iface lo inet loopback

auto $main_interface
iface $main_interface inet static
    address $ip_addr/$prefix
    gateway $gateway

# vmbr0 - 独立IP网桥
auto vmbr0
iface vmbr0 inet static
    address $ip_addr/$prefix
    gateway $gateway
    bridge_ports $main_interface
    bridge_stp off
    bridge_fd 0

# vmbr1 - NAT网桥
auto vmbr1
iface vmbr1 inet static
    address 172.16.1.1/24
    bridge_ports none
    bridge_stp off
    bridge_fd 0
    post-up echo 1 > /proc/sys/net/ipv4/ip_forward
    post-up iptables -t nat -A POSTROUTING -s 172.16.1.0/24 -o vmbr0 -j MASQUERADE
    post-down iptables -t nat -D POSTROUTING -s 172.16.1.0/24 -o vmbr0 -j MASQUERADE
EOF
    fi
    
    # 设置DNS
    cat > /etc/resolv.conf <<EOF
nameserver 8.8.8.8
nameserver 1.1.1.1
EOF
    
    # 添加DNS检测服务
    cat > /etc/systemd/system/dns-check.service <<EOF
[Unit]
Description=DNS connectivity check
After=network.target

[Service]
Type=simple
ExecStart=/bin/sh -c 'ping -c 1 8.8.8.8 || echo "nameserver 8.8.8.8" > /etc/resolv.conf'
Restart=on-failure
RestartSec=30

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl enable dns-check.service
    
    log_info "PVE安装完成，系统将在60秒后重启..."
    # 设置定时重启
    (sleep 60 && reboot) &
}

# 运行主函数
main() {
    log_info "开始PVE安装和配置..."
    check_system
    check_hardware
    check_virtualization
    check_network
    create_swap
    install_pve
}

main 