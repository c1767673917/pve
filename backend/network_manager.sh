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

# 检查PVE是否已安装
if ! command -v qm &> /dev/null; then
    log_error "未检测到PVE安装，请先运行install.sh安装PVE"
fi

# 配置网络
setup_network() {
    log_info "开始配置网络..."
    
    # 备份当前的网络配置
    cp /etc/network/interfaces /etc/network/interfaces.bak.$(date +%Y%m%d%H%M%S)
    
    # 获取主网卡名称
    main_interface=$(ip route | grep default | awk '{print $5}')
    
    # 获取当前IP配置
    ip_addr=$(ip -4 addr show $main_interface | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
    gateway=$(ip route | grep default | awk '{print $3}')
    prefix=$(ip -4 addr show $main_interface | grep -oP '(?<=inet\s)\d+(\.\d+){3}/\K\d+')
    
    if [ -z "$ip_addr" ] || [ -z "$gateway" ] || [ -z "$prefix" ]; then
        log_error "无法获取网络配置信息"
    fi
    
    log_info "当前网络配置:"
    log_info "  主网卡: $main_interface"
    log_info "  IP地址: $ip_addr/$prefix"
    log_info "  网关: $gateway"
    
    # 创建网络配置
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
    
    # 检查是否有IPv6支持
    ipv6_subnet=$(ip -6 addr show dev $main_interface | grep -oP '(?<=inet6\s)[\da-f]+:[\da-f:]+(?=/64)')
    
    if [ -n "$ipv6_subnet" ]; then
        log_info "检测到IPv6子网: $ipv6_subnet/64"
        
        # 添加IPv6网桥配置
        cat >> /etc/network/interfaces <<EOF

# vmbr2 - IPv6网桥
auto vmbr2
iface vmbr2 inet6 static
    address $ipv6_subnet::1/64
    bridge_ports none
    bridge_stp off
    bridge_fd 0
EOF
        
        # 安装和配置ndppd (NDP代理守护程序，用于IPv6)
        log_info "配置IPv6 NDP代理..."
        apt-get install -y ndppd
        
        cat > /etc/ndppd.conf <<EOF
proxy vmbr0 {
  rule $ipv6_subnet::/64 {
    static
  }
}
EOF
        
        systemctl enable ndppd
        systemctl restart ndppd
    else
        log_warn "未检测到IPv6子网，不配置IPv6网桥"
    fi
    
    # 配置iptables
    log_info "配置防火墙规则..."
    
    # 允许所有已建立的连接
    iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
    
    # 允许本地回环接口
    iptables -A INPUT -i lo -j ACCEPT
    
    # 允许SSH (端口22)
    iptables -A INPUT -p tcp --dport 22 -j ACCEPT
    
    # 允许PVE Web界面 (端口8006)
    iptables -A INPUT -p tcp --dport 8006 -j ACCEPT
    
    # 允许DHCP
    iptables -A INPUT -p udp --dport 67:68 -j ACCEPT
    
    # 允许ping
    iptables -A INPUT -p icmp -j ACCEPT
    
    # 保存iptables规则
    if [ ! -d /etc/iptables ]; then
        mkdir -p /etc/iptables
    fi
    
    iptables-save > /etc/iptables/rules.v4
    
    # 配置IP转发
    log_info "配置IP转发..."
    echo "net.ipv4.ip_forward=1" > /etc/sysctl.d/99-ip-forward.conf
    
    if [ -n "$ipv6_subnet" ]; then
        echo "net.ipv6.conf.all.forwarding=1" >> /etc/sysctl.d/99-ip-forward.conf
    fi
    
    sysctl -p /etc/sysctl.d/99-ip-forward.conf
    
    log_info "网络配置完成，需要重启网络服务..."
    systemctl restart networking
    
    log_info "网络配置已应用"
}

# 检查网络状态
check_network() {
    log_info "检查网络状态..."
    
    # 显示网络接口
    log_info "网络接口状态:"
    ip a
    
    # 显示路由表
    log_info "路由表:"
    ip route
    
    # 显示IPv6路由表 (如果有IPv6)
    if ip -6 addr show | grep -q "inet6"; then
        log_info "IPv6路由表:"
        ip -6 route
    fi
    
    # 检查网桥
    log_info "网桥状态:"
    if command -v brctl &> /dev/null; then
        brctl show
    else
        log_warn "bridge-utils未安装，无法显示详细网桥信息"
        ip link | grep -A 1 "vmbr"
    fi
    
    # 检查iptables NAT规则
    log_info "iptables NAT规则:"
    iptables -t nat -L -v
    
    # 测试网络连通性
    log_info "测试网络连通性..."
    if ping -c 3 8.8.8.8 &> /dev/null; then
        log_info "网络连通性正常"
    else
        log_warn "无法连接到互联网"
    fi
}

# 重置网络配置
reset_network() {
    log_info "重置网络配置..."
    
    # 查找最早的备份
    local backup_file=$(ls -t /etc/network/interfaces.bak.* 2>/dev/null | tail -1)
    
    if [ -n "$backup_file" ]; then
        log_info "恢复备份的网络配置: $backup_file"
        cp "$backup_file" /etc/network/interfaces
    else
        log_warn "未找到备份的网络配置，将创建基本配置"
        
        # 获取主网卡名称
        main_interface=$(ip route | grep default | awk '{print $5}')
        
        # 创建基本网络配置
        cat > /etc/network/interfaces <<EOF
auto lo
iface lo inet loopback

auto $main_interface
iface $main_interface inet dhcp
EOF
    fi
    
    # 删除防火墙规则
    log_info "清除防火墙规则..."
    iptables -F
    iptables -t nat -F
    
    # 停止并禁用ndppd服务
    if systemctl is-active ndppd &> /dev/null; then
        log_info "停止ndppd服务..."
        systemctl stop ndppd
        systemctl disable ndppd
    fi
    
    # 禁用IP转发
    log_info "禁用IP转发..."
    if [ -f /etc/sysctl.d/99-ip-forward.conf ]; then
        rm -f /etc/sysctl.d/99-ip-forward.conf
    fi
    
    echo "net.ipv4.ip_forward=0" > /etc/sysctl.d/99-ip-forward.conf
    echo "net.ipv6.conf.all.forwarding=0" >> /etc/sysctl.d/99-ip-forward.conf
    sysctl -p /etc/sysctl.d/99-ip-forward.conf
    
    log_info "重启网络服务..."
    systemctl restart networking
    
    log_info "网络配置已重置"
}

# 配置端口映射
setup_port_forward() {
    if [ "$#" -lt 3 ]; then
        echo "用法: $0 port_forward 外部端口 内部IP 内部端口 [协议(默认tcp)]"
        exit 1
    fi
    
    local ext_port=$1
    local int_ip=$2
    local int_port=$3
    local protocol=${4:-"tcp"}
    
    # 验证输入
    if ! [[ "$ext_port" =~ ^[0-9]+$ ]] || [ "$ext_port" -lt 1 ] || [ "$ext_port" -gt 65535 ]; then
        log_error "外部端口必须是1-65535之间的数字"
    fi
    
    if ! [[ "$int_port" =~ ^[0-9]+$ ]] || [ "$int_port" -lt 1 ] || [ "$int_port" -gt 65535 ]; then
        log_error "内部端口必须是1-65535之间的数字"
    fi
    
    if ! [[ "$int_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        log_error "内部IP格式不正确"
    fi
    
    if [[ "$protocol" != "tcp" && "$protocol" != "udp" ]]; then
        log_error "协议必须是tcp或udp"
    fi
    
    log_info "添加端口映射: 外部端口 $ext_port ($protocol) -> $int_ip:$int_port"
    
    # 检查该端口是否已经被映射
    if iptables -t nat -L PREROUTING -v | grep -q "dpt:$ext_port"; then
        log_warn "外部端口 $ext_port 已经被映射，将替换现有规则"
        iptables -t nat -D PREROUTING -i vmbr0 -p $protocol --dport $ext_port -j DNAT --to $int_ip:$int_port 2>/dev/null || true
    fi
    
    # 添加端口映射规则
    iptables -t nat -A PREROUTING -i vmbr0 -p $protocol --dport $ext_port -j DNAT --to $int_ip:$int_port
    iptables -t nat -A POSTROUTING -s 172.16.1.0/24 -o vmbr0 -j MASQUERADE
    
    # 保存iptables规则
    iptables-save > /etc/iptables/rules.v4
    
    log_info "端口映射已添加"
}

# 删除端口映射
delete_port_forward() {
    if [ "$#" -lt 1 ]; then
        echo "用法: $0 delete_port_forward 外部端口 [协议(默认tcp)]"
        exit 1
    fi
    
    local ext_port=$1
    local protocol=${2:-"tcp"}
    
    # 验证输入
    if ! [[ "$ext_port" =~ ^[0-9]+$ ]] || [ "$ext_port" -lt 1 ] || [ "$ext_port" -gt 65535 ]; then
        log_error "外部端口必须是1-65535之间的数字"
    fi
    
    if [[ "$protocol" != "tcp" && "$protocol" != "udp" ]]; then
        log_error "协议必须是tcp或udp"
    fi
    
    log_info "删除端口映射: 外部端口 $ext_port ($protocol)"
    
    # 删除端口映射规则
    iptables -t nat -D PREROUTING -i vmbr0 -p $protocol --dport $ext_port -j DNAT --to-destination 2>/dev/null || true
    
    # 保存iptables规则
    iptables-save > /etc/iptables/rules.v4
    
    log_info "端口映射已删除"
}

# 列出所有端口映射
list_port_forwards() {
    log_info "当前端口映射列表:"
    iptables -t nat -L PREROUTING -n | grep DNAT | awk '{print $7, "->", $8}'
}

# 主函数
main() {
    if [ $# -eq 0 ]; then
        echo "用法: $0 [命令] [参数...]"
        echo ""
        echo "可用命令:"
        echo "  setup              配置网络（创建网桥、启用NAT等）"
        echo "  check              检查网络状态"
        echo "  reset              重置网络配置"
        echo "  port_forward       添加端口映射 [外部端口] [内部IP] [内部端口] [协议(默认tcp)]"
        echo "  delete_port_forward  删除端口映射 [外部端口] [协议(默认tcp)]"
        echo "  list_port_forwards 列出所有端口映射"
        exit 0
    fi
    
    local command=$1
    shift
    
    case "$command" in
        setup)
            setup_network
            ;;
        check)
            check_network
            ;;
        reset)
            reset_network
            ;;
        port_forward)
            setup_port_forward "$@"
            ;;
        delete_port_forward)
            delete_port_forward "$@"
            ;;
        list_port_forwards)
            list_port_forwards
            ;;
        *)
            log_error "未知命令: $command"
            ;;
    esac
}

main "$@" 