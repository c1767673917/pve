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

# 创建NAT虚拟机
create_nat_vm() {
    # 参数验证
    if [ "$#" -lt 10 ]; then
        echo "用法: $0 create_nat VMID 用户名 密码 CPU核数 内存(MB) 硬盘(GB) SSH端口 80端口 443端口 系统镜像 [存储盘] [是否启用IPv6]"
        exit 1
    fi
    
    local vmid=$1
    local username=$2
    local password=$3
    local cpu=$4
    local memory=$5
    local disk=$6
    local ssh_port=$7
    local http_port=$8
    local https_port=$9
    local image=${10}
    local storage=${11:-"local"}
    local ipv6=${12:-"N"}
    
    # 检查VMID是否有效
    if [ "$vmid" -lt 100 ] || [ "$vmid" -gt 999 ]; then
        log_error "VMID必须在100到999之间"
    fi
    
    # 检查VMID是否已存在
    if qm status $vmid &>/dev/null; then
        log_error "VMID $vmid 已存在"
    fi
    
    # 准备临时目录
    local temp_dir=$(mktemp -d)
    trap 'rm -rf "$temp_dir"' EXIT
    
    # 选择镜像
    local image_url=""
    case "$image" in
        debian10|debian11|debian12)
            image_url="https://cloud.debian.org/images/cloud/bullseye/latest/debian-11-genericcloud-amd64.qcow2"
            ;;
        ubuntu20|ubuntu22)
            image_url="https://cloud-images.ubuntu.com/focal/current/focal-server-cloudimg-amd64.img"
            ;;
        *)
            log_error "不支持的系统镜像: $image"
            ;;
    esac
    
    # 下载镜像
    log_info "正在下载系统镜像..."
    wget -q --show-progress -O "$temp_dir/vm.qcow2" "$image_url"
    
    # 创建虚拟机
    log_info "创建虚拟机 (VMID: $vmid)..."
    qm create $vmid \
        --name "vm-$vmid" \
        --memory $memory \
        --cores $cpu \
        --net0 "virtio,bridge=vmbr1" \
        --ipconfig0 "ip=172.16.1.$((vmid-100+10))/24,gw=172.16.1.1" \
        --ostype l26 \
        --serial0 socket \
        --vga serial0 \
        --agent enabled=1 \
        --boot c \
        --bootdisk virtio0 \
        --onboot 1
    
    # 导入磁盘
    log_info "导入磁盘镜像..."
    qm importdisk $vmid "$temp_dir/vm.qcow2" $storage
    
    # 配置磁盘
    qm set $vmid --virtio0 $storage:vm-$vmid-disk-0
    qm resize $vmid virtio0 ${disk}G
    
    # 配置Cloudinit
    qm set $vmid --ide2 $storage:cloudinit
    qm set $vmid --ciuser $username
    qm set $vmid --cipassword $password
    qm set $vmid --sshkeys ~/.ssh/authorized_keys 2>/dev/null || true
    
    # 端口映射
    log_info "配置端口映射..."
    # SSH端口映射
    iptables -t nat -A PREROUTING -i vmbr0 -p tcp --dport $ssh_port -j DNAT --to 172.16.1.$((vmid-100+10)):22
    iptables -t nat -A POSTROUTING -s 172.16.1.0/24 -o vmbr0 -j MASQUERADE
    # HTTP端口映射
    iptables -t nat -A PREROUTING -i vmbr0 -p tcp --dport $http_port -j DNAT --to 172.16.1.$((vmid-100+10)):80
    # HTTPS端口映射
    iptables -t nat -A PREROUTING -i vmbr0 -p tcp --dport $https_port -j DNAT --to 172.16.1.$((vmid-100+10)):443
    
    # 保存iptables规则
    iptables-save > /etc/iptables/rules.v4
    
    # 配置IPv6（如果需要）
    if [ "$ipv6" = "Y" ] || [ "$ipv6" = "y" ]; then
        log_info "配置IPv6..."
        local ipv6_subnet=$(ip -6 addr show dev vmbr0 | grep -oP '(?<=inet6\s)[\da-f]+:[\da-f:]+(?=/64)')
        if [ -n "$ipv6_subnet" ]; then
            qm set $vmid --ipconfig0 "ip=172.16.1.$((vmid-100+10))/24,gw=172.16.1.1,ip6=$ipv6_subnet::$((vmid-100+10))/64"
            log_info "已配置IPv6地址: $ipv6_subnet::$((vmid-100+10))"
        else
            log_warn "未检测到IPv6子网，跳过IPv6配置"
        fi
    fi
    
    # 创建VM信息文件
    cat > vm$vmid <<EOF
VM信息:
VMID: $vmid
用户名: $username
密码: $password
CPU: $cpu核
内存: ${memory}MB
硬盘: ${disk}G
SSH端口: $ssh_port
HTTP端口: $http_port
HTTPS端口: $https_port
系统: $image
存储盘: $storage
IPv6: $ipv6
内部IP: 172.16.1.$((vmid-100+10))
EOF
    
    # 添加到VM的Notes
    qm set $vmid --description "$(cat vm$vmid)"
    
    # 启动虚拟机
    log_info "启动虚拟机..."
    qm start $vmid
    
    log_info "虚拟机创建成功，详细信息:"
    cat vm$vmid
}

# 创建独立IP虚拟机
create_direct_ip_vm() {
    # 参数验证
    if [ "$#" -lt 9 ]; then
        echo "用法: $0 create_direct VMID 用户名 密码 CPU核数 内存(MB) 硬盘(GB) 系统镜像 存储盘 IP地址 [子网掩码] [IPv6]"
        exit 1
    fi
    
    local vmid=$1
    local username=$2
    local password=$3
    local cpu=$4
    local memory=$5
    local disk=$6
    local image=$7
    local storage=$8
    local ip_addr=$9
    local subnet=${10:-"24"}
    local ipv6=${11:-"N"}
    
    # 检查VMID是否有效
    if [ "$vmid" -lt 100 ] || [ "$vmid" -gt 999 ]; then
        log_error "VMID必须在100到999之间"
    fi
    
    # 检查VMID是否已存在
    if qm status $vmid &>/dev/null; then
        log_error "VMID $vmid 已存在"
    fi
    
    # 获取网关
    local gateway=$(ip route | grep default | awk '{print $3}')
    
    # 准备临时目录
    local temp_dir=$(mktemp -d)
    trap 'rm -rf "$temp_dir"' EXIT
    
    # 选择镜像
    local image_url=""
    case "$image" in
        debian10|debian11|debian12)
            image_url="https://cloud.debian.org/images/cloud/bullseye/latest/debian-11-genericcloud-amd64.qcow2"
            ;;
        ubuntu20|ubuntu22)
            image_url="https://cloud-images.ubuntu.com/focal/current/focal-server-cloudimg-amd64.img"
            ;;
        *)
            log_error "不支持的系统镜像: $image"
            ;;
    esac
    
    # 下载镜像
    log_info "正在下载系统镜像..."
    wget -q --show-progress -O "$temp_dir/vm.qcow2" "$image_url"
    
    # 创建虚拟机
    log_info "创建虚拟机 (VMID: $vmid)..."
    qm create $vmid \
        --name "vm-$vmid" \
        --memory $memory \
        --cores $cpu \
        --net0 "virtio,bridge=vmbr0" \
        --ipconfig0 "ip=$ip_addr/$subnet,gw=$gateway" \
        --ostype l26 \
        --serial0 socket \
        --vga serial0 \
        --agent enabled=1 \
        --boot c \
        --bootdisk virtio0 \
        --onboot 1
    
    # 导入磁盘
    log_info "导入磁盘镜像..."
    qm importdisk $vmid "$temp_dir/vm.qcow2" $storage
    
    # 配置磁盘
    qm set $vmid --virtio0 $storage:vm-$vmid-disk-0
    qm resize $vmid virtio0 ${disk}G
    
    # 配置Cloudinit
    qm set $vmid --ide2 $storage:cloudinit
    qm set $vmid --ciuser $username
    qm set $vmid --cipassword $password
    qm set $vmid --sshkeys ~/.ssh/authorized_keys 2>/dev/null || true
    
    # 配置IPv6（如果需要）
    if [ "$ipv6" = "Y" ] || [ "$ipv6" = "y" ]; then
        log_info "配置IPv6..."
        local ipv6_subnet=$(ip -6 addr show dev vmbr0 | grep -oP '(?<=inet6\s)[\da-f]+:[\da-f:]+(?=/64)')
        if [ -n "$ipv6_subnet" ]; then
            qm set $vmid --ipconfig0 "ip=$ip_addr/$subnet,gw=$gateway,ip6=$ipv6_subnet::$((vmid-100+10))/64"
            log_info "已配置IPv6地址: $ipv6_subnet::$((vmid-100+10))"
        else
            log_warn "未检测到IPv6子网，跳过IPv6配置"
        fi
    fi
    
    # 创建VM信息文件
    cat > vm$vmid <<EOF
VM信息:
VMID: $vmid
用户名: $username
密码: $password
CPU: $cpu核
内存: ${memory}MB
硬盘: ${disk}G
系统: $image
存储盘: $storage
IP地址: $ip_addr/$subnet
网关: $gateway
IPv6: $ipv6
EOF
    
    # 添加到VM的Notes
    qm set $vmid --description "$(cat vm$vmid)"
    
    # 启动虚拟机
    log_info "启动虚拟机..."
    qm start $vmid
    
    log_info "虚拟机创建成功，详细信息:"
    cat vm$vmid
}

# 创建纯IPv6虚拟机
create_ipv6_vm() {
    # 参数验证
    if [ "$#" -lt 8 ]; then
        echo "用法: $0 create_ipv6 VMID 用户名 密码 CPU核数 内存(MB) 硬盘(GB) 系统镜像 存储盘"
        exit 1
    fi
    
    local vmid=$1
    local username=$2
    local password=$3
    local cpu=$4
    local memory=$5
    local disk=$6
    local image=$7
    local storage=$8
    
    # 检查是否有IPv6支持
    local ipv6_subnet=$(ip -6 addr show dev vmbr0 | grep -oP '(?<=inet6\s)[\da-f]+:[\da-f:]+(?=/64)')
    if [ -z "$ipv6_subnet" ]; then
        log_error "未检测到IPv6子网，无法创建纯IPv6虚拟机"
    fi
    
    # 检查VMID是否有效
    if [ "$vmid" -lt 100 ] || [ "$vmid" -gt 999 ]; then
        log_error "VMID必须在100到999之间"
    fi
    
    # 检查VMID是否已存在
    if qm status $vmid &>/dev/null; then
        log_error "VMID $vmid 已存在"
    fi
    
    # 准备临时目录
    local temp_dir=$(mktemp -d)
    trap 'rm -rf "$temp_dir"' EXIT
    
    # 选择镜像
    local image_url=""
    case "$image" in
        debian10|debian11|debian12)
            image_url="https://cloud.debian.org/images/cloud/bullseye/latest/debian-11-genericcloud-amd64.qcow2"
            ;;
        ubuntu20|ubuntu22)
            image_url="https://cloud-images.ubuntu.com/focal/current/focal-server-cloudimg-amd64.img"
            ;;
        *)
            log_error "不支持的系统镜像: $image"
            ;;
    esac
    
    # 下载镜像
    log_info "正在下载系统镜像..."
    wget -q --show-progress -O "$temp_dir/vm.qcow2" "$image_url"
    
    # 创建虚拟机
    log_info "创建虚拟机 (VMID: $vmid)..."
    qm create $vmid \
        --name "vm-$vmid" \
        --memory $memory \
        --cores $cpu \
        --net0 "virtio,bridge=vmbr2" \
        --ipconfig0 "ip=dhcp,ip6=$ipv6_subnet::$((vmid-100+10))/64" \
        --ostype l26 \
        --serial0 socket \
        --vga serial0 \
        --agent enabled=1 \
        --boot c \
        --bootdisk virtio0 \
        --onboot 1
    
    # 导入磁盘
    log_info "导入磁盘镜像..."
    qm importdisk $vmid "$temp_dir/vm.qcow2" $storage
    
    # 配置磁盘
    qm set $vmid --virtio0 $storage:vm-$vmid-disk-0
    qm resize $vmid virtio0 ${disk}G
    
    # 配置Cloudinit
    qm set $vmid --ide2 $storage:cloudinit
    qm set $vmid --ciuser $username
    qm set $vmid --cipassword $password
    qm set $vmid --sshkeys ~/.ssh/authorized_keys 2>/dev/null || true
    
    # 创建VM信息文件
    cat > vm$vmid <<EOF
VM信息:
VMID: $vmid
用户名: $username
密码: $password
CPU: $cpu核
内存: ${memory}MB
硬盘: ${disk}G
系统: $image
存储盘: $storage
IPv6地址: $ipv6_subnet::$((vmid-100+10))/64
EOF
    
    # 添加到VM的Notes
    qm set $vmid --description "$(cat vm$vmid)"
    
    # 启动虚拟机
    log_info "启动虚拟机..."
    qm start $vmid
    
    log_info "虚拟机创建成功，详细信息:"
    cat vm$vmid
}

# 删除虚拟机
delete_vm() {
    if [ "$#" -lt 1 ]; then
        echo "用法: $0 delete VMID [VMID2 VMID3 ...]"
        exit 1
    fi
    
    for vmid in "$@"; do
        log_info "删除虚拟机 $vmid..."
        
        # 检查VM是否存在
        if ! qm status $vmid &>/dev/null; then
            log_warn "VMID $vmid 不存在，跳过删除"
            continue
        fi
        
        # 停止虚拟机
        log_info "停止虚拟机 $vmid..."
        qm stop $vmid &>/dev/null || true
        sleep 3
        
        # 获取VM信息用于删除端口映射
        if [ -f "vm$vmid" ]; then
            # 删除NAT端口映射
            if grep -q "SSH端口" "vm$vmid"; then
                local ssh_port=$(grep "SSH端口" "vm$vmid" | awk '{print $2}')
                local http_port=$(grep "HTTP端口" "vm$vmid" | awk '{print $2}')
                local https_port=$(grep "HTTPS端口" "vm$vmid" | awk '{print $2}')
                local internal_ip=$(grep "内部IP" "vm$vmid" | awk '{print $2}')
                
                log_info "删除端口映射..."
                
                # 删除SSH端口映射
                iptables -t nat -D PREROUTING -i vmbr0 -p tcp --dport $ssh_port -j DNAT --to $internal_ip:22 2>/dev/null || true
                
                # 删除HTTP端口映射
                iptables -t nat -D PREROUTING -i vmbr0 -p tcp --dport $http_port -j DNAT --to $internal_ip:80 2>/dev/null || true
                
                # 删除HTTPS端口映射
                iptables -t nat -D PREROUTING -i vmbr0 -p tcp --dport $https_port -j DNAT --to $internal_ip:443 2>/dev/null || true
                
                # 保存iptables规则
                iptables-save > /etc/iptables/rules.v4
            fi
            
            # 删除VM信息文件
            rm -f "vm$vmid"
        fi
        
        # 销毁虚拟机
        log_info "销毁虚拟机 $vmid..."
        qm destroy $vmid
        
        log_info "虚拟机 $vmid 已删除"
    done
}

# 列出所有虚拟机
list_vms() {
    log_info "列出所有虚拟机..."
    qm list
}

# 启动虚拟机
start_vm() {
    if [ "$#" -lt 1 ]; then
        echo "用法: $0 start VMID"
        exit 1
    fi
    
    local vmid=$1
    
    # 检查VM是否存在
    if ! qm status $vmid &>/dev/null; then
        log_error "VMID $vmid 不存在"
    fi
    
    # 启动虚拟机
    log_info "启动虚拟机 $vmid..."
    qm start $vmid
    
    log_info "虚拟机 $vmid 已启动"
}

# 停止虚拟机
stop_vm() {
    if [ "$#" -lt 1 ]; then
        echo "用法: $0 stop VMID"
        exit 1
    fi
    
    local vmid=$1
    
    # 检查VM是否存在
    if ! qm status $vmid &>/dev/null; then
        log_error "VMID $vmid 不存在"
    fi
    
    # 停止虚拟机
    log_info "停止虚拟机 $vmid..."
    qm stop $vmid
    
    log_info "虚拟机 $vmid 已停止"
}

# 重启虚拟机
restart_vm() {
    if [ "$#" -lt 1 ]; then
        echo "用法: $0 restart VMID"
        exit 1
    fi
    
    local vmid=$1
    
    # 检查VM是否存在
    if ! qm status $vmid &>/dev/null; then
        log_error "VMID $vmid 不存在"
    fi
    
    # 重启虚拟机
    log_info "重启虚拟机 $vmid..."
    qm reboot $vmid
    
    log_info "虚拟机 $vmid 正在重启"
}

# 显示虚拟机信息
show_vm() {
    if [ "$#" -lt 1 ]; then
        echo "用法: $0 show VMID"
        exit 1
    fi
    
    local vmid=$1
    
    # 检查VM是否存在
    if ! qm status $vmid &>/dev/null; then
        log_error "VMID $vmid 不存在"
    fi
    
    # 显示虚拟机配置
    qm config $vmid
    
    # 显示VM信息文件
    if [ -f "vm$vmid" ]; then
        echo -e "\n虚拟机详细信息:"
        cat "vm$vmid"
    fi
}

# 批量创建NAT虚拟机
batch_create_nat_vms() {
    echo "批量创建NAT虚拟机"
    echo "===================="
    
    read -p "开始VMID [默认: 100]: " start_vmid
    start_vmid=${start_vmid:-100}
    
    read -p "创建数量 [默认: 5]: " vm_count
    vm_count=${vm_count:-5}
    
    read -p "CPU核数 [默认: 1]: " cpu
    cpu=${cpu:-1}
    
    read -p "内存大小(MB) [默认: 512]: " memory
    memory=${memory:-512}
    
    read -p "硬盘大小(GB) [默认: 10]: " disk
    disk=${disk:-10}
    
    read -p "系统镜像 [默认: debian11]: " image
    image=${image:-debian11}
    
    read -p "存储盘 [默认: local]: " storage
    storage=${storage:-local}
    
    read -p "密码前缀 [默认: oneclick]: " password_prefix
    password_prefix=${password_prefix:-oneclick}
    
    read -p "启用IPv6? [Y/n]: " ipv6
    ipv6=${ipv6:-n}
    
    # 起始端口
    local start_ssh_port=40000
    local start_http_port=41000
    local start_https_port=42000
    
    for ((i=0; i<vm_count; i++)); do
        local current_vmid=$((start_vmid + i))
        local username="user$current_vmid"
        local password="${password_prefix}${current_vmid}"
        local ssh_port=$((start_ssh_port + i))
        local http_port=$((start_http_port + i))
        local https_port=$((start_https_port + i))
        
        log_info "正在创建第 $((i+1))/$vm_count 个虚拟机 (VMID: $current_vmid)..."
        
        create_nat_vm $current_vmid $username $password $cpu $memory $disk $ssh_port $http_port $https_port $image $storage $ipv6
        
        # 等待一段时间，避免资源争用
        sleep 5
    done
    
    log_info "批量创建完成，共创建 $vm_count 个虚拟机"
}

# 主函数
main() {
    if [ $# -eq 0 ]; then
        echo "用法: $0 [命令] [参数...]"
        echo ""
        echo "可用命令:"
        echo "  create_nat VMID 用户名 密码 CPU核数 内存 硬盘 SSH端口 80端口 443端口 系统 [存储盘] [IPv6]"
        echo "  create_direct VMID 用户名 密码 CPU核数 内存 硬盘 系统 存储盘 IP地址 [子网掩码] [IPv6]"
        echo "  create_ipv6 VMID 用户名 密码 CPU核数 内存 硬盘 系统 存储盘"
        echo "  batch_create 批量创建NAT虚拟机"
        echo "  delete VMID [VMID2 VMID3 ...]"
        echo "  list 列出所有虚拟机"
        echo "  start VMID"
        echo "  stop VMID"
        echo "  restart VMID"
        echo "  show VMID"
        exit 0
    fi
    
    local command=$1
    shift
    
    case "$command" in
        create_nat)
            create_nat_vm "$@"
            ;;
        create_direct)
            create_direct_ip_vm "$@"
            ;;
        create_ipv6)
            create_ipv6_vm "$@"
            ;;
        batch_create)
            batch_create_nat_vms
            ;;
        delete)
            delete_vm "$@"
            ;;
        list)
            list_vms
            ;;
        start)
            start_vm "$@"
            ;;
        stop)
            stop_vm "$@"
            ;;
        restart)
            restart_vm "$@"
            ;;
        show)
            show_vm "$@"
            ;;
        *)
            log_error "未知命令: $command"
            ;;
    esac
}

main "$@" 