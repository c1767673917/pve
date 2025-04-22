/**
 * PVE KVM 管理系统前端JavaScript
 */

document.addEventListener('DOMContentLoaded', function() {
    // 初始化页面
    initTabs();
    initDashboard();
    initVMList();
    initCreateVMForm();
    initNetworkTab();
    initSettings();
    initEventListeners();
});

// API接口URL
const API_BASE_URL = 'api.php';

/**
 * 初始化标签切换
 */
function initTabs() {
    const navLinks = document.querySelectorAll('.nav-link');
    const tabContents = document.querySelectorAll('.tab-content');

    // 切换标签页显示
    navLinks.forEach(link => {
        link.addEventListener('click', (e) => {
            e.preventDefault();
            
            // 移除所有active类
            navLinks.forEach(l => l.classList.remove('active'));
            tabContents.forEach(t => t.classList.remove('active'));
            
            // 添加active类到当前选中的标签
            link.classList.add('active');
            
            // 获取目标标签内容ID
            const targetId = link.getAttribute('href').substring(1);
            document.getElementById(targetId).classList.add('active');
        });
    });

    // 快速创建虚拟机按钮
    document.getElementById('btn-create-vm').addEventListener('click', () => {
        navLinks.forEach(l => l.classList.remove('active'));
        tabContents.forEach(t => t.classList.remove('active'));
        
        document.querySelector('a[href="#create-vm"]').classList.add('active');
        document.getElementById('create-vm').classList.add('active');
    });

    // 网络配置按钮
    document.getElementById('btn-network-setup').addEventListener('click', () => {
        navLinks.forEach(l => l.classList.remove('active'));
        tabContents.forEach(t => t.classList.remove('active'));
        
        document.querySelector('a[href="#network"]').classList.add('active');
        document.getElementById('network').classList.add('active');
    });
}

/**
 * 初始化控制面板
 */
function initDashboard() {
    // 获取系统信息
    fetchSystemInfo();
    
    // 获取虚拟机统计信息
    fetchVMStats();
    
    // 定时刷新数据
    setInterval(fetchSystemInfo, 10000);
    setInterval(fetchVMStats, 30000);
}

/**
 * 获取系统信息
 */
function fetchSystemInfo() {
    // 模拟API请求
    // 实际应用中应该调用后端API获取真实数据
    
    // 模拟数据
    const systemInfo = {
        hostname: 'pve.example.com',
        osVersion: 'Debian 11 (Bullseye)',
        pveVersion: 'Proxmox VE 7.4-3',
        ipAddress: '192.168.1.100',
        uptime: '10 days, 5 hours, 30 minutes',
        cpu: {
            usage: 25,
            cores: 4,
            model: 'Intel(R) Xeon(R) CPU E5-2670'
        },
        memory: {
            total: 8192,
            used: 3072,
            usage: 37.5
        },
        disk: {
            total: 100,
            used: 35,
            usage: 35
        }
    };
    
    // 更新UI
    document.getElementById('hostname').textContent = systemInfo.hostname;
    document.getElementById('os-version').textContent = systemInfo.osVersion;
    document.getElementById('pve-version').textContent = systemInfo.pveVersion;
    document.getElementById('ip-address').textContent = systemInfo.ipAddress;
    document.getElementById('uptime').textContent = systemInfo.uptime;
    
    // 更新进度条
    const cpuProgress = document.getElementById('cpu-usage');
    cpuProgress.style.width = `${systemInfo.cpu.usage}%`;
    cpuProgress.textContent = `${systemInfo.cpu.usage}%`;
    
    const memoryProgress = document.getElementById('memory-usage');
    memoryProgress.style.width = `${systemInfo.memory.usage}%`;
    memoryProgress.textContent = `${systemInfo.memory.usage}%`;
    
    const diskProgress = document.getElementById('disk-usage');
    diskProgress.style.width = `${systemInfo.disk.usage}%`;
    diskProgress.textContent = `${systemInfo.disk.usage}%`;
}

/**
 * 获取虚拟机统计信息
 */
function fetchVMStats() {
    // 模拟API请求
    // 实际应用中应该调用后端API获取真实数据
    
    // 模拟数据
    const vmStats = {
        total: 5,
        running: 3,
        stopped: 2
    };
    
    // 更新UI
    document.getElementById('total-vms').textContent = vmStats.total;
    document.getElementById('running-vms').textContent = vmStats.running;
    document.getElementById('stopped-vms').textContent = vmStats.stopped;
}

/**
 * 初始化虚拟机列表
 */
function initVMList() {
    // 获取虚拟机列表
    fetchVMList();
    
    // 刷新按钮事件
    document.getElementById('refresh-vm-list').addEventListener('click', fetchVMList);
    
    // 新建虚拟机按钮事件
    document.getElementById('add-vm-btn').addEventListener('click', () => {
        document.querySelector('a[href="#create-vm"]').click();
    });
}

/**
 * 获取虚拟机列表
 */
function fetchVMList() {
    // 显示加载中
    document.getElementById('vm-list-body').innerHTML = '<tr><td colspan="9" class="text-center">加载中...</td></tr>';
    
    // 模拟API请求
    // 实际应用中应该调用后端API获取真实数据
    setTimeout(() => {
        // 模拟数据
        const vms = [
            {
                vmid: 100,
                name: 'vm-debian11',
                status: 'running',
                cpu: 1,
                memory: 1024,
                disk: 10,
                netType: 'nat',
                ipv4: '172.16.1.10',
                ipv6: 'fd00::10',
                username: 'user100',
                password: 'oneclick100',
                os: 'debian11',
                storage: 'local',
                ports: {
                    ssh: 40001,
                    http: 40002,
                    https: 40003
                }
            },
            {
                vmid: 101,
                name: 'vm-ubuntu20',
                status: 'stopped',
                cpu: 2,
                memory: 2048,
                disk: 20,
                netType: 'direct',
                ipv4: '192.168.1.101',
                ipv6: '',
                username: 'user101',
                password: 'oneclick101',
                os: 'ubuntu20',
                storage: 'local'
            },
            {
                vmid: 102,
                name: 'vm-debian12',
                status: 'running',
                cpu: 1,
                memory: 512,
                disk: 15,
                netType: 'ipv6',
                ipv4: '',
                ipv6: 'fd00::102',
                username: 'user102',
                password: 'oneclick102',
                os: 'debian12',
                storage: 'local'
            }
        ];
        
        // 更新UI
        const tableBody = document.getElementById('vm-list-body');
        tableBody.innerHTML = '';
        
        vms.forEach(vm => {
            const tr = document.createElement('tr');
            
            // 状态图标样式
            const statusClass = vm.status === 'running' ? 'vm-status-running' : 'vm-status-stopped';
            const statusText = vm.status === 'running' ? '运行中' : '已停止';
            
            // 网络类型图标
            let netTypeIcon, netTypeText;
            switch(vm.netType) {
                case 'nat':
                    netTypeIcon = 'bi-diagram-3';
                    netTypeText = 'NAT网络';
                    break;
                case 'direct':
                    netTypeIcon = 'bi-globe';
                    netTypeText = '独立IP';
                    break;
                case 'ipv6':
                    netTypeIcon = 'bi-globe2';
                    netTypeText = '纯IPv6';
                    break;
                default:
                    netTypeIcon = 'bi-question-circle';
                    netTypeText = '未知';
            }
            
            tr.innerHTML = `
                <td>${vm.vmid}</td>
                <td>${vm.name}</td>
                <td>
                    <span class="vm-status-indicator ${statusClass}"></span>
                    ${statusText}
                </td>
                <td>${vm.cpu}核</td>
                <td>${vm.memory}MB</td>
                <td>${vm.disk}GB</td>
                <td>
                    <i class="bi ${netTypeIcon} network-type-icon"></i>
                    ${netTypeText}
                </td>
                <td>
                    ${vm.ipv4 ? `<span class="ip-address">${vm.ipv4}</span><br>` : ''}
                    ${vm.ipv6 ? `<span class="ip-address">${vm.ipv6}</span>` : ''}
                </td>
                <td class="vm-actions">
                    ${vm.status === 'running' 
                        ? `<button class="btn btn-sm btn-outline-warning btn-action" onclick="stopVM(${vm.vmid})"><i class="bi bi-stop-circle"></i></button>`
                        : `<button class="btn btn-sm btn-outline-success btn-action" onclick="startVM(${vm.vmid})"><i class="bi bi-play-circle"></i></button>`
                    }
                    <button class="btn btn-sm btn-outline-primary btn-action" onclick="showVMDetails(${vm.vmid})"><i class="bi bi-info-circle"></i></button>
                    <button class="btn btn-sm btn-outline-danger btn-action" onclick="confirmDeleteVM(${vm.vmid})"><i class="bi bi-trash"></i></button>
                </td>
            `;
            
            tableBody.appendChild(tr);
        });
    }, 500);
}

/**
 * 显示虚拟机详情
 */
function showVMDetails(vmid) {
    // 模拟API请求获取虚拟机详情
    // 实际应用中应该调用后端API
    
    // 模拟数据 (根据VMID查找)
    const vm = {
        vmid: vmid,
        name: `vm-${vmid}`,
        status: vmid % 2 === 0 ? 'running' : 'stopped',
        cpu: 1,
        memory: 1024,
        disk: 10,
        netType: 'nat',
        ipv4: `172.16.1.${vmid - 90}`,
        ipv6: `fd00::${vmid}`,
        username: `user${vmid}`,
        password: `oneclick${vmid}`,
        os: 'debian11',
        storage: 'local',
        ports: {
            ssh: 40000 + (vmid - 100) * 3,
            http: 40001 + (vmid - 100) * 3,
            https: 40002 + (vmid - 100) * 3
        }
    };
    
    // 更新模态框内容
    document.getElementById('detail-vmid').textContent = vm.vmid;
    document.getElementById('detail-name').textContent = vm.name;
    document.getElementById('detail-status').textContent = vm.status === 'running' ? '运行中' : '已停止';
    document.getElementById('detail-os').textContent = vm.os;
    
    document.getElementById('detail-cpu').textContent = `${vm.cpu}核`;
    document.getElementById('detail-memory').textContent = `${vm.memory}MB`;
    document.getElementById('detail-disk').textContent = `${vm.disk}GB`;
    document.getElementById('detail-storage').textContent = vm.storage;
    
    // 网络类型
    let netTypeText;
    switch(vm.netType) {
        case 'nat':
            netTypeText = 'NAT网络';
            break;
        case 'direct':
            netTypeText = '独立IP';
            break;
        case 'ipv6':
            netTypeText = '纯IPv6';
            break;
        default:
            netTypeText = '未知';
    }
    document.getElementById('detail-nettype').textContent = netTypeText;
    document.getElementById('detail-ipv4').textContent = vm.ipv4 || '无';
    document.getElementById('detail-ipv6').textContent = vm.ipv6 || '无';
    
    // 端口映射
    const portsBody = document.getElementById('detail-ports-body');
    portsBody.innerHTML = '';
    
    if (vm.netType === 'nat' && vm.ports) {
        document.getElementById('detail-port-mappings').style.display = 'block';
        
        // SSH端口
        if (vm.ports.ssh) {
            const tr = document.createElement('tr');
            tr.innerHTML = `
                <td>SSH</td>
                <td>${vm.ports.ssh}</td>
                <td>22</td>
            `;
            portsBody.appendChild(tr);
        }
        
        // HTTP端口
        if (vm.ports.http) {
            const tr = document.createElement('tr');
            tr.innerHTML = `
                <td>HTTP</td>
                <td>${vm.ports.http}</td>
                <td>80</td>
            `;
            portsBody.appendChild(tr);
        }
        
        // HTTPS端口
        if (vm.ports.https) {
            const tr = document.createElement('tr');
            tr.innerHTML = `
                <td>HTTPS</td>
                <td>${vm.ports.https}</td>
                <td>443</td>
            `;
            portsBody.appendChild(tr);
        }
        
        // SSH访问命令
        document.getElementById('detail-ssh-row').style.display = 'table-row';
        const sshCmd = `ssh ${vm.username}@${vm.ipv4} -p ${vm.ports.ssh}`;
        document.getElementById('detail-ssh-cmd').textContent = sshCmd;
    } else {
        document.getElementById('detail-port-mappings').style.display = 'none';
        
        // 对于非NAT网络，显示SSH命令如果有IPv4
        if (vm.ipv4) {
            document.getElementById('detail-ssh-row').style.display = 'table-row';
            const sshCmd = `ssh ${vm.username}@${vm.ipv4}`;
            document.getElementById('detail-ssh-cmd').textContent = sshCmd;
        } else if (vm.ipv6) {
            document.getElementById('detail-ssh-row').style.display = 'table-row';
            const sshCmd = `ssh ${vm.username}@[${vm.ipv6}]`;
            document.getElementById('detail-ssh-cmd').textContent = sshCmd;
        } else {
            document.getElementById('detail-ssh-row').style.display = 'none';
        }
    }
    
    // 登录信息
    document.getElementById('detail-username').textContent = vm.username;
    document.getElementById('detail-password').textContent = vm.password;
    
    // 显示模态框
    const modal = new bootstrap.Modal(document.getElementById('vm-details-modal'));
    modal.show();
}

/**
 * 启动虚拟机
 */
function startVM(vmid) {
    // 模拟API请求
    // 实际应用中应该调用后端API
    
    console.log(`启动虚拟机 ${vmid}`);
    
    // 显示加载中状态
    alert(`正在启动虚拟机 ${vmid}，请稍候...`);
    
    // 刷新虚拟机列表
    setTimeout(fetchVMList, 1000);
}

/**
 * 停止虚拟机
 */
function stopVM(vmid) {
    // 模拟API请求
    // 实际应用中应该调用后端API
    
    console.log(`停止虚拟机 ${vmid}`);
    
    // 显示加载中状态
    alert(`正在停止虚拟机 ${vmid}，请稍候...`);
    
    // 刷新虚拟机列表
    setTimeout(fetchVMList, 1000);
}

/**
 * 确认删除虚拟机
 */
function confirmDeleteVM(vmid) {
    if (confirm(`确定要删除虚拟机 ${vmid} 吗？此操作不可恢复！`)) {
        deleteVM(vmid);
    }
}

/**
 * 删除虚拟机
 */
function deleteVM(vmid) {
    // 模拟API请求
    // 实际应用中应该调用后端API
    
    console.log(`删除虚拟机 ${vmid}`);
    
    // 显示加载中状态
    alert(`正在删除虚拟机 ${vmid}，请稍候...`);
    
    // 刷新虚拟机列表
    setTimeout(fetchVMList, 1000);
}

/**
 * 初始化创建虚拟机表单
 */
function initCreateVMForm() {
    // 表单重置按钮
    document.getElementById('reset-form').addEventListener('click', () => {
        document.getElementById('create-vm-form').reset();
    });
    
    // 生成随机密码按钮
    document.getElementById('generate-password').addEventListener('click', () => {
        const password = generateRandomPassword(12);
        document.getElementById('vm-password').value = password;
    });
    
    // 虚拟机类型切换事件
    const vmTypeRadios = document.getElementsByName('vm-type');
    vmTypeRadios.forEach(radio => {
        radio.addEventListener('change', () => {
            const vmType = document.querySelector('input[name="vm-type"]:checked').value;
            
            // 根据选择的类型显示/隐藏相应设置
            if (vmType === 'nat') {
                document.getElementById('nat-settings').style.display = 'block';
                document.getElementById('direct-settings').style.display = 'none';
            } else if (vmType === 'direct') {
                document.getElementById('nat-settings').style.display = 'none';
                document.getElementById('direct-settings').style.display = 'block';
            } else if (vmType === 'ipv6') {
                document.getElementById('nat-settings').style.display = 'none';
                document.getElementById('direct-settings').style.display = 'none';
            }
        });
    });
    
    // 表单提交事件
    document.getElementById('create-vm-form').addEventListener('submit', (e) => {
        e.preventDefault();
        createVM();
    });
}

/**
 * 生成随机密码
 */
function generateRandomPassword(length = 12) {
    const charset = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*';
    let password = '';
    
    // 确保密码至少包含一个小写字母、一个大写字母、一个数字和一个特殊字符
    password += 'abcdefghijklmnopqrstuvwxyz'[Math.floor(Math.random() * 26)];
    password += 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'[Math.floor(Math.random() * 26)];
    password += '0123456789'[Math.floor(Math.random() * 10)];
    password += '!@#$%^&*'[Math.floor(Math.random() * 8)];
    
    // 填充剩余长度
    for (let i = 4; i < length; i++) {
        password += charset[Math.floor(Math.random() * charset.length)];
    }
    
    // 洗牌
    password = password.split('').sort(() => 0.5 - Math.random()).join('');
    
    return password;
}

/**
 * 创建虚拟机
 */
function createVM() {
    // 获取表单数据
    const vmType = document.querySelector('input[name="vm-type"]:checked').value;
    const vmid = document.getElementById('vm-id').value;
    const username = document.getElementById('vm-name').value;
    const password = document.getElementById('vm-password').value;
    const cpu = document.getElementById('vm-cpu').value;
    const memory = document.getElementById('vm-memory').value;
    const disk = document.getElementById('vm-disk').value;
    const os = document.getElementById('vm-os').value;
    const storage = document.getElementById('vm-storage').value;
    const ipv6Enabled = document.getElementById('vm-ipv6-enabled').checked;
    
    // 根据虚拟机类型获取特定参数
    let params = {};
    
    if (vmType === 'nat') {
        params.sshPort = document.getElementById('vm-ssh-port').value;
        params.httpPort = document.getElementById('vm-http-port').value;
        params.httpsPort = document.getElementById('vm-https-port').value;
    } else if (vmType === 'direct') {
        params.ipAddress = document.getElementById('vm-ip-address').value;
        params.subnet = document.getElementById('vm-subnet').value;
    }
    
    // 构建请求数据
    const requestData = {
        vmType,
        vmid,
        username,
        password,
        cpu,
        memory,
        disk,
        os,
        storage,
        ipv6Enabled,
        ...params
    };
    
    console.log('创建虚拟机请求数据:', requestData);
    
    // 模拟API请求
    // 实际应用中应该调用后端API
    alert('正在创建虚拟机，请稍候...');
    
    // 模拟创建成功
    setTimeout(() => {
        alert(`虚拟机创建成功！VMID: ${vmid}`);
        
        // 重置表单
        document.getElementById('create-vm-form').reset();
        
        // 切换到虚拟机列表
        document.querySelector('a[href="#vm-list"]').click();
        
        // 刷新虚拟机列表
        fetchVMList();
    }, 2000);
}

/**
 * 初始化网络标签页
 */
function initNetworkTab() {
    // 刷新网络接口按钮
    document.getElementById('refresh-interfaces').addEventListener('click', fetchNetworkInterfaces);
    
    // 添加端口映射按钮
    document.getElementById('add-port-forward').addEventListener('click', showAddPortForwardModal);
    
    // 保存端口映射按钮
    document.getElementById('save-port-forward').addEventListener('click', savePortForward);
    
    // 获取网络接口信息
    fetchNetworkInterfaces();
    
    // 获取端口映射信息
    fetchPortForwards();
    
    // 获取IPv6信息
    fetchIPv6Info();
}

/**
 * 获取网络接口信息
 */
function fetchNetworkInterfaces() {
    // 显示加载中
    document.getElementById('interfaces-list').innerHTML = '<tr><td colspan="6" class="text-center">加载中...</td></tr>';
    
    // 模拟API请求
    // 实际应用中应该调用后端API
    setTimeout(() => {
        // 模拟数据
        const interfaces = [
            {
                name: 'eth0',
                type: '物理网卡',
                status: 'up',
                ipv4: '192.168.1.100/24',
                ipv6: 'fd00::1/64',
                mac: '00:11:22:33:44:55'
            },
            {
                name: 'vmbr0',
                type: '桥接网卡',
                status: 'up',
                ipv4: '192.168.1.100/24',
                ipv6: 'fd00::1/64',
                mac: '00:11:22:33:44:56'
            },
            {
                name: 'vmbr1',
                type: 'NAT网桥',
                status: 'up',
                ipv4: '172.16.1.1/24',
                ipv6: '',
                mac: '00:11:22:33:44:57'
            },
            {
                name: 'vmbr2',
                type: 'IPv6网桥',
                status: 'up',
                ipv4: '',
                ipv6: 'fd00::1/64',
                mac: '00:11:22:33:44:58'
            }
        ];
        
        // 更新UI
        const tableBody = document.getElementById('interfaces-list');
        tableBody.innerHTML = '';
        
        interfaces.forEach(iface => {
            const tr = document.createElement('tr');
            
            const statusClass = iface.status === 'up' ? 'text-success' : 'text-danger';
            const statusText = iface.status === 'up' ? '正常' : '关闭';
            
            tr.innerHTML = `
                <td>${iface.name}</td>
                <td>${iface.type}</td>
                <td class="${statusClass}">${statusText}</td>
                <td>${iface.ipv4 || '-'}</td>
                <td>${iface.ipv6 || '-'}</td>
                <td>${iface.mac}</td>
            `;
            
            tableBody.appendChild(tr);
        });
    }, 500);
}

/**
 * 获取端口映射信息
 */
function fetchPortForwards() {
    // 显示加载中
    document.getElementById('port-forward-list').innerHTML = '<tr><td colspan="5" class="text-center">加载中...</td></tr>';
    
    // 模拟API请求
    // 实际应用中应该调用后端API
    setTimeout(() => {
        // 模拟数据
        const portForwards = [
            {
                extPort: 40001,
                protocol: 'tcp',
                intIP: '172.16.1.10',
                intPort: 22
            },
            {
                extPort: 40002,
                protocol: 'tcp',
                intIP: '172.16.1.10',
                intPort: 80
            },
            {
                extPort: 40003,
                protocol: 'tcp',
                intIP: '172.16.1.10',
                intPort: 443
            },
            {
                extPort: 40004,
                protocol: 'udp',
                intIP: '172.16.1.11',
                intPort: 51820
            }
        ];
        
        // 更新UI
        const tableBody = document.getElementById('port-forward-list');
        tableBody.innerHTML = '';
        
        portForwards.forEach(pf => {
            const tr = document.createElement('tr');
            
            tr.innerHTML = `
                <td>${pf.extPort}</td>
                <td>${pf.protocol.toUpperCase()}</td>
                <td>${pf.intIP}</td>
                <td>${pf.intPort}</td>
                <td>
                    <button class="btn btn-sm btn-outline-danger" onclick="deletePortForward(${pf.extPort}, '${pf.protocol}')">
                        <i class="bi bi-trash"></i>
                    </button>
                </td>
            `;
            
            tableBody.appendChild(tr);
        });
    }, 500);
}

/**
 * 获取IPv6信息
 */
function fetchIPv6Info() {
    // 模拟API请求
    // 实际应用中应该调用后端API
    
    // 模拟数据
    const ipv6Info = {
        subnet: 'fd00::/64',
        gateway: 'fd00::1',
        enabled: true
    };
    
    // 更新UI
    document.getElementById('ipv6-subnet').value = ipv6Info.subnet;
    document.getElementById('ipv6-gateway').value = ipv6Info.gateway;
    document.getElementById('ipv6-enabled').checked = ipv6Info.enabled;
}

/**
 * 显示添加端口映射模态框
 */
function showAddPortForwardModal() {
    // 重置表单
    document.getElementById('port-forward-form').reset();
    
    // 显示模态框
    const modal = new bootstrap.Modal(document.getElementById('add-port-modal'));
    modal.show();
}

/**
 * 保存端口映射
 */
function savePortForward() {
    // 获取表单数据
    const externalPort = document.getElementById('port-external').value;
    const internalIP = document.getElementById('port-internal-ip').value;
    const internalPort = document.getElementById('port-internal').value;
    const protocol = document.getElementById('port-protocol').value;
    
    // 验证表单数据
    if (!externalPort || !internalIP || !internalPort) {
        alert('请填写完整的表单信息');
        return;
    }
    
    // 模拟API请求
    // 实际应用中应该调用后端API
    console.log('添加端口映射:', {
        externalPort,
        internalIP,
        internalPort,
        protocol
    });
    
    // 隐藏模态框
    const modal = bootstrap.Modal.getInstance(document.getElementById('add-port-modal'));
    modal.hide();
    
    // 显示成功消息
    alert('端口映射添加成功');
    
    // 刷新端口映射列表
    fetchPortForwards();
}

/**
 * 删除端口映射
 */
function deletePortForward(port, protocol) {
    if (confirm(`确定要删除端口 ${port} (${protocol}) 的映射吗？`)) {
        // 模拟API请求
        // 实际应用中应该调用后端API
        console.log(`删除端口映射: ${port} (${protocol})`);
        
        // 显示成功消息
        alert('端口映射删除成功');
        
        // 刷新端口映射列表
        fetchPortForwards();
    }
}

/**
 * 初始化系统设置
 */
function initSettings() {
    // 备份配置按钮
    document.getElementById('backup-config').addEventListener('click', backupConfig);
    
    // 恢复配置按钮
    document.getElementById('restore-config').addEventListener('click', restoreConfig);
    
    // 检查更新按钮
    document.getElementById('check-updates').addEventListener('click', checkUpdates);
    
    // 重启系统按钮
    document.getElementById('restart-system').addEventListener('click', confirmRestartSystem);
}

/**
 * 备份配置
 */
function backupConfig() {
    // 模拟API请求
    // 实际应用中应该调用后端API
    
    alert('系统配置备份中，请稍候...');
    
    // 模拟备份完成
    setTimeout(() => {
        alert('系统配置备份完成，备份文件已保存至: /root/pve_backup_20231020123456');
    }, 1000);
}

/**
 * 恢复配置
 */
function restoreConfig() {
    const backupPath = prompt('请输入备份路径:', '/root/pve_backup_20231020123456');
    
    if (backupPath) {
        // 模拟API请求
        // 实际应用中应该调用后端API
        
        alert('正在恢复系统配置，请稍候...');
        
        // 模拟恢复完成
        setTimeout(() => {
            alert('系统配置恢复完成，系统服务已重启');
        }, 1000);
    }
}

/**
 * 检查更新
 */
function checkUpdates() {
    // 模拟API请求
    // 实际应用中应该调用后端API
    
    alert('正在检查系统更新，请稍候...');
    
    // 模拟检查结果
    setTimeout(() => {
        alert('系统已是最新版本');
    }, 1000);
}

/**
 * 确认重启系统
 */
function confirmRestartSystem() {
    if (confirm('确定要重启系统吗？所有正在运行的虚拟机将会被强制关闭！')) {
        restartSystem();
    }
}

/**
 * 重启系统
 */
function restartSystem() {
    // 模拟API请求
    // 实际应用中应该调用后端API
    
    alert('系统正在重启，请稍候...');
    
    // 模拟重启
    setTimeout(() => {
        alert('系统已重启完成，请刷新页面');
    }, 3000);
}

/**
 * 初始化事件监听器
 */
function initEventListeners() {
    // 在此处添加其他全局事件监听器
} 