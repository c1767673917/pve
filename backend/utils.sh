#!/bin/bash

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
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "此脚本必须使用root权限运行"
    fi
}

# 检查PVE是否已安装
check_pve_installed() {
    if ! command -v qm &> /dev/null; then
        log_error "未检测到PVE安装，请先运行install.sh安装PVE"
    fi
}

# 检查系统是否为Debian
check_debian() {
    if [ ! -f /etc/debian_version ]; then
        log_error "不支持的系统，本套脚本仅支持Debian系统"
    fi
    
    source /etc/os-release
    if [ "$VERSION_ID" -lt 8 ]; then
        log_error "系统版本过低，需要Debian 8+"
    fi
    
    log_info "检测到系统为: Debian $VERSION_ID"
}

# 获取随机端口
get_random_port() {
    local min=${1:-10000}
    local max=${2:-60000}
    
    # 检查端口是否已使用
    local port=$((RANDOM % (max - min) + min))
    while netstat -tuln | grep -q ":$port "; do
        port=$((RANDOM % (max - min) + min))
    done
    
    echo $port
}

# 检查端口是否可用
check_port_available() {
    local port=$1
    
    if netstat -tuln | grep -q ":$port "; then
        return 1
    else
        return 0
    fi
}

# 生成随机字符串
generate_random_string() {
    local length=${1:-12}
    cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w ${length} | head -n 1
}

# 生成随机密码
generate_random_password() {
    local length=${1:-16}
    local password=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9!@#$%^&*()-_=+' | fold -w ${length} | head -n 1)
    
    # 确保至少包含一个大写字母、一个小写字母、一个数字和一个特殊字符
    while [[ ! $password =~ [A-Z] ]] || [[ ! $password =~ [a-z] ]] || [[ ! $password =~ [0-9] ]] || [[ ! $password =~ [!@#$%^&*()-_=+] ]]; do
        password=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9!@#$%^&*()-_=+' | fold -w ${length} | head -n 1)
    done
    
    echo $password
}

# 检查IP格式是否正确
validate_ip() {
    local ip=$1
    
    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        # 检查每个部分是否在0-255之间
        IFS='.' read -ra ADDR <<< "$ip"
        for i in "${ADDR[@]}"; do
            if [ $i -lt 0 ] || [ $i -gt 255 ]; then
                return 1
            fi
        done
        return 0
    else
        return 1
    fi
}

# 检查IPv6格式是否正确
validate_ipv6() {
    local ipv6=$1
    
    # 简单检查，使用ping6测试可达性
    if [[ $ipv6 =~ .*:.* ]]; then
        if ping6 -c 1 -W 1 $ipv6 &>/dev/null; then
            return 0
        fi
    fi
    return 1
}

# 检查端口范围是否合法
validate_port() {
    local port=$1
    
    if ! [[ "$port" =~ ^[0-9]+$ ]] || [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
        return 1
    fi
    return 0
}

# 检查虚拟化支持
check_virtualization() {
    # 检查CPU是否支持虚拟化
    if grep -E 'vmx|svm' /proc/cpuinfo > /dev/null; then
        log_info "检测到CPU支持虚拟化"
        return 0
    else
        log_warn "CPU可能不支持硬件虚拟化，将使用QEMU软件模拟"
        return 1
    fi
}

# 检查KVM模块是否加载
check_kvm_loaded() {
    if lsmod | grep -i kvm > /dev/null; then
        log_info "检测到KVM模块已加载"
        return 0
    else
        log_warn "KVM模块未加载，可能无法使用KVM加速"
        return 1
    fi
}

# 检查网络连通性
check_internet() {
    if ping -c 1 -W 2 8.8.8.8 > /dev/null 2>&1; then
        log_info "检测到互联网连接正常"
        return 0
    else
        log_warn "互联网连接可能不可用"
        return 1
    fi
}

# 检查是否在中国网络环境
check_china_network() {
    if ping -c 1 -W 2 www.baidu.com > /dev/null 2>&1; then
        log_info "检测到中国网络环境"
        return 0
    else
        return 1
    fi
}

# 检查硬件配置是否满足最低要求
check_hardware_requirements() {
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
    
    if [ $cpu_cores -lt 1 ] || [ $total_mem -lt 1024 ] || [ ${free_disk%.*} -lt 10 ]; then
        log_error "硬件配置不满足最低要求"
    fi
}

# 获取Web界面URL
get_web_url() {
    local ip_addr=$(hostname -I | awk '{print $1}')
    local port=8006
    
    echo "https://$ip_addr:$port"
}

# 安装常用工具
install_common_tools() {
    log_info "安装常用工具..."
    apt-get update
    apt-get install -y curl wget vim htop net-tools screen iptables iptables-persistent
}

# 设置时区为亚洲/上海
set_timezone_china() {
    log_info "设置时区为亚洲/上海..."
    timedatectl set-timezone Asia/Shanghai
}

# 创建或导入SSH密钥
create_ssh_key() {
    local key_file=${1:-~/.ssh/id_rsa}
    
    if [ ! -f "$key_file" ]; then
        log_info "创建SSH密钥..."
        ssh-keygen -t rsa -b 4096 -f "$key_file" -N ""
    fi
    
    # 确保authorized_keys文件存在
    if [ ! -f ~/.ssh/authorized_keys ]; then
        touch ~/.ssh/authorized_keys
        chmod 600 ~/.ssh/authorized_keys
    fi
    
    # 将公钥添加到authorized_keys文件中
    if [ -f "${key_file}.pub" ]; then
        cat "${key_file}.pub" >> ~/.ssh/authorized_keys
    fi
}

# 获取主网卡名称
get_main_interface() {
    ip route | grep default | awk '{print $5}'
}

# 获取当前IP地址
get_ip_address() {
    local interface=${1:-$(get_main_interface)}
    ip -4 addr show $interface | grep -oP '(?<=inet\s)\d+(\.\d+){3}'
}

# 获取网关
get_gateway() {
    ip route | grep default | awk '{print $3}'
}

# 获取子网前缀
get_prefix() {
    local interface=${1:-$(get_main_interface)}
    ip -4 addr show $interface | grep -oP '(?<=inet\s)\d+(\.\d+){3}/\K\d+'
}

# 获取IPv6子网
get_ipv6_subnet() {
    local interface=${1:-$(get_main_interface)}
    ip -6 addr show dev $interface | grep -oP '(?<=inet6\s)[\da-f]+:[\da-f:]+(?=/64)'
}

# 计算下一个可用的IPV4地址
get_next_available_ip() {
    local base_ip=$1  # 例如 192.168.1
    local start=${2:-2}
    local end=${3:-254}
    
    for ((i=start; i<=end; i++)); do
        local ip="$base_ip.$i"
        if ! ping -c 1 -W 1 $ip &>/dev/null; then
            echo $ip
            return 0
        fi
    done
    
    log_error "无法找到可用的IP地址"
}

# 检查存储是否存在
check_storage_exists() {
    local storage=$1
    
    if pvesm status | grep -q "^$storage "; then
        return 0
    else
        return 1
    fi
}

# 检查VMID是否可用
check_vmid_available() {
    local vmid=$1
    
    if qm list | grep -q "^\s*$vmid "; then
        return 1
    else
        return 0
    fi
}

# 获取下一个可用的VMID
get_next_available_vmid() {
    local start=${1:-100}
    local end=${2:-999}
    
    for ((i=start; i<=end; i++)); do
        if check_vmid_available $i; then
            echo $i
            return 0
        fi
    done
    
    log_error "无法找到可用的VMID"
}

# 显示PVE状态概览
show_pve_status() {
    log_info "PVE状态概览:"
    
    echo "系统信息:"
    uname -a
    
    echo -e "\nCPU使用率:"
    top -bn1 | grep "Cpu(s)" | awk '{print $2 + $4 "% 用户空间, " $6 + $8 + $10 "% 系统空间"}'
    
    echo -e "\n内存使用情况:"
    free -h
    
    echo -e "\n磁盘使用情况:"
    df -h
    
    echo -e "\n虚拟机列表:"
    qm list
    
    echo -e "\n存储状态:"
    pvesm status
    
    echo -e "\n网络接口:"
    ip a
    
    echo -e "\nWeb界面: $(get_web_url)"
}

# 检查新版本
check_update() {
    log_info "检查更新..."
    
    apt-get update
    
    local updates=$(apt-get upgrade -s | grep -c ^Inst)
    
    if [ $updates -gt 0 ]; then
        log_warn "有 $updates 个包可以更新"
        read -p "是否立即更新? [y/N] " update_now
        
        if [[ "$update_now" =~ ^[Yy]$ ]]; then
            log_info "正在更新系统..."
            apt-get upgrade -y
            log_info "系统更新完成"
        else
            log_info "跳过系统更新"
        fi
    else
        log_info "系统已是最新状态"
    fi
}

# 下载KVM镜像
download_kvm_image() {
    local image=$1
    local output_file=${2:-"./vm.qcow2"}
    local base_url="https://cloud.debian.org/images/cloud/bullseye/latest"
    
    case "$image" in
        debian10)
            url="https://cloud.debian.org/images/cloud/buster/latest/debian-10-genericcloud-amd64.qcow2"
            ;;
        debian11)
            url="https://cloud.debian.org/images/cloud/bullseye/latest/debian-11-genericcloud-amd64.qcow2"
            ;;
        debian12)
            url="https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-genericcloud-amd64.qcow2"
            ;;
        ubuntu20)
            url="https://cloud-images.ubuntu.com/focal/current/focal-server-cloudimg-amd64.img"
            ;;
        ubuntu22)
            url="https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"
            ;;
        *)
            log_error "不支持的系统镜像: $image"
            ;;
    esac
    
    # 使用中国镜像源（如果在中国网络环境）
    if check_china_network; then
        case "$image" in
            debian*)
                url=${url/cloud.debian.org/mirrors.tuna.tsinghua.edu.cn\/debian-cd}
                ;;
            ubuntu*)
                url=${url/cloud-images.ubuntu.com/mirrors.tuna.tsinghua.edu.cn\/ubuntu-cloud-images}
                ;;
        esac
    fi
    
    log_info "开始下载镜像: $image"
    log_info "下载地址: $url"
    
    wget -O "$output_file" "$url" || {
        log_error "下载镜像失败"
    }
    
    log_info "镜像下载完成: $output_file"
}

# 备份系统配置
backup_system_config() {
    local backup_dir=${1:-"/root/pve_backup_$(date +%Y%m%d%H%M%S)"}
    mkdir -p "$backup_dir"
    
    log_info "备份系统配置到 $backup_dir..."
    
    # 备份网络配置
    cp -v /etc/network/interfaces "$backup_dir/"
    
    # 备份防火墙规则
    if [ -f /etc/iptables/rules.v4 ]; then
        cp -v /etc/iptables/rules.v4 "$backup_dir/"
    else
        iptables-save > "$backup_dir/iptables_rules.v4"
    fi
    
    # 备份IPv6相关配置
    if [ -f /etc/ndppd.conf ]; then
        cp -v /etc/ndppd.conf "$backup_dir/"
    fi
    
    # 备份DNS配置
    cp -v /etc/resolv.conf "$backup_dir/"
    
    # 备份关键PVE配置
    mkdir -p "$backup_dir/etc/pve"
    if [ -d /etc/pve ]; then
        cp -rv /etc/pve/storage.cfg "$backup_dir/etc/pve/" 2>/dev/null || true
        cp -rv /etc/pve/nodes "$backup_dir/etc/pve/" 2>/dev/null || true
    fi
    
    log_info "系统配置已备份到 $backup_dir"
}

# 恢复系统配置
restore_system_config() {
    local backup_dir=$1
    
    if [ ! -d "$backup_dir" ]; then
        log_error "备份目录不存在: $backup_dir"
    fi
    
    log_info "从 $backup_dir 恢复系统配置..."
    
    # 恢复网络配置
    if [ -f "$backup_dir/interfaces" ]; then
        cp -v "$backup_dir/interfaces" /etc/network/interfaces
    fi
    
    # 恢复防火墙规则
    if [ -f "$backup_dir/rules.v4" ]; then
        mkdir -p /etc/iptables
        cp -v "$backup_dir/rules.v4" /etc/iptables/
        iptables-restore < /etc/iptables/rules.v4
    elif [ -f "$backup_dir/iptables_rules.v4" ]; then
        iptables-restore < "$backup_dir/iptables_rules.v4"
    fi
    
    # 恢复IPv6相关配置
    if [ -f "$backup_dir/ndppd.conf" ]; then
        cp -v "$backup_dir/ndppd.conf" /etc/
        systemctl restart ndppd 2>/dev/null || true
    fi
    
    # 恢复DNS配置
    if [ -f "$backup_dir/resolv.conf" ]; then
        cp -v "$backup_dir/resolv.conf" /etc/
    fi
    
    # 恢复关键PVE配置
    if [ -d "$backup_dir/etc/pve" ]; then
        mkdir -p /etc/pve
        if [ -f "$backup_dir/etc/pve/storage.cfg" ]; then
            cp -v "$backup_dir/etc/pve/storage.cfg" /etc/pve/
        fi
        if [ -d "$backup_dir/etc/pve/nodes" ]; then
            cp -rv "$backup_dir/etc/pve/nodes" /etc/pve/
        fi
    fi
    
    log_info "系统配置已恢复，需要重启网络服务..."
    systemctl restart networking
    
    log_info "系统配置恢复完成"
}

# 记录系统日志
log_to_file() {
    local message=$1
    local log_file=${2:-"/var/log/pve_manager.log"}
    
    # 确保日志目录存在
    mkdir -p $(dirname "$log_file")
    
    # 记录到日志文件
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $message" >> "$log_file"
}

# 显示帮助
show_help() {
    echo "PVE KVM管理工具 - 工具函数"
    echo "用法: source utils.sh"
    echo ""
    echo "可用函数:"
    echo "  log_info, log_warn, log_error              - 日志输出函数"
    echo "  check_root                                 - 检查是否为root用户"
    echo "  check_pve_installed                        - 检查PVE是否已安装"
    echo "  check_debian                               - 检查系统是否为Debian"
    echo "  get_random_port [min] [max]                - 获取随机未使用端口"
    echo "  check_port_available [port]                - 检查端口是否可用"
    echo "  generate_random_string [length]            - 生成随机字符串"
    echo "  generate_random_password [length]          - 生成随机密码"
    echo "  validate_ip [ip]                           - 检查IP格式是否正确"
    echo "  validate_ipv6 [ipv6]                       - 检查IPv6格式是否正确"
    echo "  validate_port [port]                       - 检查端口范围是否合法"
    echo "  check_virtualization                       - 检查虚拟化支持"
    echo "  check_kvm_loaded                           - 检查KVM模块是否加载"
    echo "  check_internet                             - 检查网络连通性"
    echo "  check_china_network                        - 检查是否在中国网络环境"
    echo "  check_hardware_requirements                - 检查硬件配置是否满足最低要求"
    echo "  get_web_url                                - 获取Web界面URL"
    echo "  install_common_tools                       - 安装常用工具"
    echo "  set_timezone_china                         - 设置时区为亚洲/上海"
    echo "  create_ssh_key [key_file]                  - 创建或导入SSH密钥"
    echo "  get_main_interface                         - 获取主网卡名称"
    echo "  get_ip_address [interface]                 - 获取当前IP地址"
    echo "  get_gateway                                - 获取网关"
    echo "  get_prefix [interface]                     - 获取子网前缀"
    echo "  get_ipv6_subnet [interface]                - 获取IPv6子网"
    echo "  get_next_available_ip [base_ip] [start] [end] - 计算下一个可用的IPV4地址"
    echo "  check_storage_exists [storage]             - 检查存储是否存在"
    echo "  check_vmid_available [vmid]                - 检查VMID是否可用"
    echo "  get_next_available_vmid [start] [end]      - 获取下一个可用的VMID"
    echo "  show_pve_status                            - 显示PVE状态概览"
    echo "  check_update                               - 检查新版本"
    echo "  download_kvm_image [image] [output_file]   - 下载KVM镜像"
    echo "  backup_system_config [backup_dir]          - 备份系统配置"
    echo "  restore_system_config [backup_dir]         - 恢复系统配置"
    echo "  log_to_file [message] [log_file]           - 记录系统日志"
}

# 如果直接运行此脚本，显示帮助
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    show_help
fi 