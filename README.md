# PVE KVM 虚拟化管理系统

一个基于Proxmox VE的KVM虚拟化快速部署和管理工具，提供简单易用的Web界面和一套自动化脚本，帮助你快速部署和管理KVM虚拟机。

## 功能特点

- 一键安装PVE环境，自动配置网络
- 支持创建NAT网络、独立IP和纯IPv6的虚拟机
- 提供简洁直观的Web管理界面
- 支持端口映射和网络管理
- 系统状态监控和资源使用情况展示
- 批量创建和管理虚拟机
- 自动备份和恢复系统配置

## 系统要求

- 操作系统：Debian 8+（推荐Debian 12）
- 硬件要求：2核2G内存x86_64或arm架构服务器，硬盘至少20G
- 虚拟化支持：KVM硬件虚拟化支持（VM-X或AMD-V）
- 网络环境：至少一个可用的IPv4地址

## 快速开始

### 安装

1. 克隆仓库到本地

```bash
git clone https://github.com/yourusername/pve-kvm-manager.git
cd pve-kvm-manager
```

2. 执行安装脚本

```bash
./backend/install.sh
```

3. 等待安装完成，系统将自动重启

4. 重启后，配置网络环境

```bash
./backend/network_manager.sh setup
```

5. 访问Web管理界面

打开浏览器，访问 `https://服务器IP:8006`，使用SSH的用户名和密码登录PVE管理界面。

然后访问 `http://服务器IP/pve-manager` 使用本项目的Web管理界面。

### 创建虚拟机

#### 通过Web界面

1. 在Web界面点击"创建虚拟机"标签
2. 填写虚拟机配置信息
3. 点击"创建"按钮

#### 通过命令行

创建NAT网络的虚拟机:

```bash
./backend/vm_manager.sh create_nat VMID 用户名 密码 CPU核数 内存 硬盘 SSH端口 HTTP端口 HTTPS端口 系统 存储盘 IPv6
```

例如:

```bash
./backend/vm_manager.sh create_nat 100 user100 password123 1 1024 10 40001 40002 40003 debian11 local N
```

创建独立IP的虚拟机:

```bash
./backend/vm_manager.sh create_direct VMID 用户名 密码 CPU核数 内存 硬盘 系统 存储盘 IP地址 子网掩码 IPv6
```

创建纯IPv6的虚拟机:

```bash
./backend/vm_manager.sh create_ipv6 VMID 用户名 密码 CPU核数 内存 硬盘 系统 存储盘
```

### 批量创建虚拟机

```bash
./backend/vm_manager.sh batch_create
```

然后按照提示输入参数。

## 项目结构

```
pve-manager/
├── backend/
│   ├── install.sh          # 主安装脚本
│   ├── vm_manager.sh       # 虚拟机管理脚本
│   ├── network_manager.sh  # 网络管理脚本
│   └── utils.sh            # 工具函数
├── frontend/
│   ├── index.html          # 主页面
│   ├── css/                # 样式文件
│   ├── js/                 # JavaScript文件
│   └── api.php             # 后端API接口
└── README.md               # 说明文档
```

## 支持的系统镜像

- Debian 10/11/12
- Ubuntu 20.04/22.04

## 常见问题

### 虚拟机启动失败

如果虚拟机无法启动，请检查以下几点：

- 检查宿主机是否支持KVM虚拟化
- 检查网络配置是否正确
- 查看虚拟机日志，在Web界面或使用 `qm showcmd VMID` 命令

### 网络配置问题

如果遇到网络配置问题，可以尝试：

```bash
./backend/network_manager.sh reset
./backend/network_manager.sh setup
```

### 如何进入虚拟机

对于NAT网络的虚拟机，使用以下命令：

```bash
ssh 用户名@服务器IP -p SSH端口
```

对于独立IP的虚拟机，直接SSH连接：

```bash
ssh 用户名@虚拟机IP
```

## 注意事项

- 安装过程中会改变宿主机的网络结构，请确保宿主机可以随时重置系统
- 不要在动态IP的服务器上使用本套脚本
- 请妥善保管虚拟机的登录信息
- 建议定期备份系统配置

## 贡献

欢迎提交Issue和Pull Request！

## 许可证

[MIT License](LICENSE) 