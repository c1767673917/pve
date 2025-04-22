<?php
/**
 * PVE KVM 虚拟机管理系统 API
 * 
 * 这个文件提供了Web界面与后端脚本之间的接口
 */

// 设置响应头
header('Content-Type: application/json');

// 错误处理
set_error_handler(function($severity, $message, $file, $line) {
    if (error_reporting() & $severity) {
        throw new ErrorException($message, 0, $severity, $file, $line);
    }
});

// 定义API配置
define('API_VERSION', '1.0.0');
define('BASE_DIR', dirname(__DIR__));
define('SCRIPTS_DIR', BASE_DIR . '/backend');

// 响应函数
function sendResponse($status, $data = null, $message = '') {
    $response = [
        'status' => $status,
        'message' => $message,
        'data' => $data,
        'timestamp' => time()
    ];
    echo json_encode($response, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE);
    exit;
}

// 执行shell命令
function execCommand($command) {
    $output = [];
    $exitCode = 0;
    
    exec($command . ' 2>&1', $output, $exitCode);
    
    return [
        'exit_code' => $exitCode,
        'output' => implode("\n", $output)
    ];
}

// 检查请求方法
$requestMethod = $_SERVER['REQUEST_METHOD'];
if ($requestMethod !== 'GET' && $requestMethod !== 'POST') {
    sendResponse('error', null, '不支持的请求方法');
}

// 路由分发
try {
    // 获取请求路径
    $requestUri = isset($_SERVER['PATH_INFO']) ? $_SERVER['PATH_INFO'] : '/';
    $requestUri = trim($requestUri, '/');
    
    // 解析请求参数
    $params = [];
    if ($requestMethod === 'GET') {
        $params = $_GET;
    } else {
        $rawData = file_get_contents('php://input');
        if (!empty($rawData)) {
            $params = json_decode($rawData, true) ?? [];
        }
        
        // 合并 POST 参数
        $params = array_merge($params, $_POST);
    }
    
    // API路由处理
    switch ($requestUri) {
        // 系统信息
        case 'system/info':
            $result = getSystemInfo();
            sendResponse('success', $result);
            break;
            
        // 虚拟机列表
        case 'vm/list':
            $result = getVMList();
            sendResponse('success', $result);
            break;
            
        // 虚拟机详情
        case 'vm/info':
            if (!isset($params['vmid'])) {
                sendResponse('error', null, '缺少必要参数: vmid');
            }
            
            $result = getVMInfo($params['vmid']);
            sendResponse('success', $result);
            break;
            
        // 创建虚拟机
        case 'vm/create':
            $requiredParams = ['vmType', 'vmid', 'username', 'password', 'cpu', 'memory', 'disk', 'os', 'storage'];
            foreach ($requiredParams as $param) {
                if (!isset($params[$param])) {
                    sendResponse('error', null, "缺少必要参数: $param");
                }
            }
            
            $result = createVM($params);
            sendResponse('success', $result, '虚拟机创建成功');
            break;
            
        // 启动虚拟机
        case 'vm/start':
            if (!isset($params['vmid'])) {
                sendResponse('error', null, '缺少必要参数: vmid');
            }
            
            $result = startVM($params['vmid']);
            sendResponse('success', $result, '虚拟机启动成功');
            break;
            
        // 停止虚拟机
        case 'vm/stop':
            if (!isset($params['vmid'])) {
                sendResponse('error', null, '缺少必要参数: vmid');
            }
            
            $result = stopVM($params['vmid']);
            sendResponse('success', $result, '虚拟机停止成功');
            break;
            
        // 删除虚拟机
        case 'vm/delete':
            if (!isset($params['vmid'])) {
                sendResponse('error', null, '缺少必要参数: vmid');
            }
            
            $result = deleteVM($params['vmid']);
            sendResponse('success', $result, '虚拟机删除成功');
            break;
            
        // 网络接口列表
        case 'network/interfaces':
            $result = getNetworkInterfaces();
            sendResponse('success', $result);
            break;
            
        // 端口映射列表
        case 'network/port-forwards':
            $result = getPortForwards();
            sendResponse('success', $result);
            break;
            
        // 添加端口映射
        case 'network/add-port-forward':
            $requiredParams = ['externalPort', 'internalIP', 'internalPort', 'protocol'];
            foreach ($requiredParams as $param) {
                if (!isset($params[$param])) {
                    sendResponse('error', null, "缺少必要参数: $param");
                }
            }
            
            $result = addPortForward($params);
            sendResponse('success', $result, '端口映射添加成功');
            break;
            
        // 删除端口映射
        case 'network/delete-port-forward':
            $requiredParams = ['port', 'protocol'];
            foreach ($requiredParams as $param) {
                if (!isset($params[$param])) {
                    sendResponse('error', null, "缺少必要参数: $param");
                }
            }
            
            $result = deletePortForward($params['port'], $params['protocol']);
            sendResponse('success', $result, '端口映射删除成功');
            break;
            
        // IPv6信息
        case 'network/ipv6-info':
            $result = getIPv6Info();
            sendResponse('success', $result);
            break;
            
        // 备份配置
        case 'system/backup':
            $result = backupSystem();
            sendResponse('success', $result, '系统配置备份成功');
            break;
            
        // 恢复配置
        case 'system/restore':
            if (!isset($params['backupPath'])) {
                sendResponse('error', null, '缺少必要参数: backupPath');
            }
            
            $result = restoreSystem($params['backupPath']);
            sendResponse('success', $result, '系统配置恢复成功');
            break;
            
        // 检查更新
        case 'system/check-updates':
            $result = checkUpdates();
            sendResponse('success', $result);
            break;
            
        // 重启系统
        case 'system/restart':
            $result = restartSystem();
            sendResponse('success', $result, '系统重启命令已发送');
            break;
            
        // API版本
        case 'version':
            sendResponse('success', ['version' => API_VERSION]);
            break;
            
        // 未知路由
        default:
            sendResponse('error', null, '未知的API路由');
    }
} catch (Exception $e) {
    sendResponse('error', null, '系统错误: ' . $e->getMessage());
}

/**
 * 获取系统信息
 */
function getSystemInfo() {
    // 主机名
    $hostname = trim(execCommand('hostname')['output']);
    
    // 系统版本
    $osVersionCmd = execCommand('cat /etc/os-release | grep "PRETTY_NAME" | cut -d= -f2 | tr -d \'"\'');
    $osVersion = trim($osVersionCmd['output']);
    
    // PVE版本
    $pveVersionCmd = execCommand('pveversion');
    $pveVersion = trim($pveVersionCmd['output']);
    
    // IP地址
    $ipAddressCmd = execCommand('hostname -I | awk \'{print $1}\'');
    $ipAddress = trim($ipAddressCmd['output']);
    
    // 运行时间
    $uptimeCmd = execCommand('uptime -p');
    $uptime = trim(str_replace('up ', '', $uptimeCmd['output']));
    
    // CPU信息
    $cpuInfo = [
        'usage' => 0,
        'cores' => 0,
        'model' => ''
    ];
    
    // CPU使用率
    $cpuUsageCmd = execCommand('top -bn1 | grep "Cpu(s)" | awk \'{print $2 + $4}\'');
    $cpuInfo['usage'] = (float)trim($cpuUsageCmd['output']);
    
    // CPU核心数
    $cpuCoresCmd = execCommand('nproc');
    $cpuInfo['cores'] = (int)trim($cpuCoresCmd['output']);
    
    // CPU型号
    $cpuModelCmd = execCommand('cat /proc/cpuinfo | grep "model name" | head -n1 | cut -d: -f2');
    $cpuInfo['model'] = trim($cpuModelCmd['output']);
    
    // 内存信息
    $memInfo = [
        'total' => 0,
        'used' => 0,
        'usage' => 0
    ];
    
    $memInfoCmd = execCommand('free -m | grep "Mem:"');
    $memData = preg_split('/\s+/', trim($memInfoCmd['output']));
    
    if (count($memData) >= 7) {
        $memInfo['total'] = (int)$memData[1];
        $memInfo['used'] = (int)$memData[2];
        $memInfo['usage'] = round(($memInfo['used'] / $memInfo['total']) * 100, 1);
    }
    
    // 磁盘信息
    $diskInfo = [
        'total' => 0,
        'used' => 0,
        'usage' => 0
    ];
    
    $diskInfoCmd = execCommand('df -h / | tail -n1');
    $diskData = preg_split('/\s+/', trim($diskInfoCmd['output']));
    
    if (count($diskData) >= 5) {
        $diskInfo['total'] = (float)str_replace('G', '', $diskData[1]);
        $diskInfo['used'] = (float)str_replace('G', '', $diskData[2]);
        $diskInfo['usage'] = (int)str_replace('%', '', $diskData[4]);
    }
    
    // 返回系统信息
    return [
        'hostname' => $hostname,
        'osVersion' => $osVersion,
        'pveVersion' => $pveVersion,
        'ipAddress' => $ipAddress,
        'uptime' => $uptime,
        'cpu' => $cpuInfo,
        'memory' => $memInfo,
        'disk' => $diskInfo
    ];
}

/**
 * 获取虚拟机列表
 */
function getVMList() {
    $command = 'qm list';
    $result = execCommand($command);
    
    if ($result['exit_code'] !== 0) {
        throw new Exception('获取虚拟机列表失败: ' . $result['output']);
    }
    
    $lines = explode("\n", $result['output']);
    $vms = [];
    
    // 跳过表头
    for ($i = 1; $i < count($lines); $i++) {
        $line = trim($lines[$i]);
        if (empty($line)) continue;
        
        $parts = preg_split('/\s+/', $line);
        if (count($parts) >= 4) {
            $vmid = $parts[0];
            $name = $parts[1];
            $status = $parts[2];
            
            // 获取虚拟机配置
            $configCommand = "qm config $vmid";
            $configResult = execCommand($configCommand);
            $config = parseVMConfig($configResult['output']);
            
            $vms[] = [
                'vmid' => (int)$vmid,
                'name' => $name,
                'status' => $status,
                'cpu' => $config['cpu'] ?? 1,
                'memory' => $config['memory'] ?? 512,
                'disk' => $config['disk'] ?? 0,
                'netType' => $config['netType'] ?? 'unknown',
                'ipv4' => $config['ipv4'] ?? '',
                'ipv6' => $config['ipv6'] ?? ''
            ];
        }
    }
    
    return $vms;
}

/**
 * 解析虚拟机配置
 */
function parseVMConfig($configOutput) {
    $config = [
        'cpu' => 1,
        'memory' => 512,
        'disk' => 0,
        'netType' => 'unknown',
        'ipv4' => '',
        'ipv6' => ''
    ];
    
    $lines = explode("\n", $configOutput);
    
    foreach ($lines as $line) {
        // CPU
        if (preg_match('/^cores:\s+(\d+)/', $line, $matches)) {
            $config['cpu'] = (int)$matches[1];
        }
        
        // 内存
        if (preg_match('/^memory:\s+(\d+)/', $line, $matches)) {
            $config['memory'] = (int)$matches[1];
        }
        
        // 磁盘
        if (preg_match('/^virtio0:\s+\w+:vm-\d+-disk-0,size=(\d+)G/', $line, $matches)) {
            $config['disk'] = (int)$matches[1];
        }
        
        // 网络类型和IP
        if (preg_match('/^net0:\s+virtio,bridge=(\w+)/', $line, $matches)) {
            $bridge = $matches[1];
            
            if ($bridge === 'vmbr0') {
                $config['netType'] = 'direct';
            } elseif ($bridge === 'vmbr1') {
                $config['netType'] = 'nat';
            } elseif ($bridge === 'vmbr2') {
                $config['netType'] = 'ipv6';
            }
        }
        
        // IP配置
        if (preg_match('/^ipconfig0:\s+(.+)/', $line, $matches)) {
            $ipConfig = $matches[1];
            
            // IPv4
            if (preg_match('/ip=([^\/,]+)/', $ipConfig, $ipMatches)) {
                $config['ipv4'] = $ipMatches[1];
            }
            
            // IPv6
            if (preg_match('/ip6=([^\/,]+)/', $ipConfig, $ip6Matches)) {
                $config['ipv6'] = $ip6Matches[1];
            }
        }
    }
    
    return $config;
}

/**
 * 获取虚拟机详情
 */
function getVMInfo($vmid) {
    // 检查虚拟机是否存在
    $checkCommand = "qm status $vmid";
    $checkResult = execCommand($checkCommand);
    
    if ($checkResult['exit_code'] !== 0) {
        throw new Exception("虚拟机 $vmid 不存在");
    }
    
    // 获取基本信息
    $listCommand = "qm list | grep -w $vmid";
    $listResult = execCommand($listCommand);
    $listParts = preg_split('/\s+/', trim($listResult['output']));
    
    // 获取配置
    $configCommand = "qm config $vmid";
    $configResult = execCommand($configCommand);
    $config = parseVMConfig($configResult['output']);
    
    // 读取VM信息文件
    $infoFile = "/root/vm$vmid";
    $infoContent = '';
    if (file_exists($infoFile)) {
        $infoContent = file_get_contents($infoFile);
    }
    
    // 从信息文件中提取额外信息
    $username = '';
    $password = '';
    $sshPort = 0;
    $httpPort = 0;
    $httpsPort = 0;
    $os = '';
    $storage = '';
    
    if (!empty($infoContent)) {
        // 用户名
        if (preg_match('/用户名:\s+(.+)/', $infoContent, $matches)) {
            $username = trim($matches[1]);
        }
        
        // 操作系统
        if (preg_match('/系统:\s+(.+)/', $infoContent, $matches)) {
            $os = trim($matches[1]);
        }
        
        // 存储
        if (preg_match('/存储盘:\s+(.+)/', $infoContent, $matches)) {
            $storage = trim($matches[1]);
        }
        
        // SSH端口
        if (preg_match('/SSH端口:\s+(\d+)/', $infoContent, $matches)) {
            $sshPort = (int)$matches[1];
        }
        
        // HTTP端口
        if (preg_match('/HTTP端口:\s+(\d+)/', $infoContent, $matches)) {
            $httpPort = (int)$matches[1];
        }
        
        // HTTPS端口
        if (preg_match('/HTTPS端口:\s+(\d+)/', $infoContent, $matches)) {
            $httpsPort = (int)$matches[1];
        }
    }
    
    // 组装详细信息
    $info = [
        'vmid' => (int)$vmid,
        'name' => $listParts[1] ?? "vm-$vmid",
        'status' => $listParts[2] ?? 'unknown',
        'cpu' => $config['cpu'],
        'memory' => $config['memory'],
        'disk' => $config['disk'],
        'netType' => $config['netType'],
        'ipv4' => $config['ipv4'],
        'ipv6' => $config['ipv6'],
        'username' => $username,
        'password' => $password,
        'os' => $os,
        'storage' => $storage,
        'ports' => [
            'ssh' => $sshPort,
            'http' => $httpPort,
            'https' => $httpsPort
        ]
    ];
    
    return $info;
}

/**
 * 创建虚拟机
 */
function createVM($params) {
    $vmType = $params['vmType'];
    $vmid = $params['vmid'];
    $username = $params['username'];
    $password = $params['password'];
    $cpu = $params['cpu'];
    $memory = $params['memory'];
    $disk = $params['disk'];
    $os = $params['os'];
    $storage = $params['storage'];
    $ipv6Enabled = isset($params['ipv6Enabled']) && $params['ipv6Enabled'] ? 'Y' : 'N';
    
    // 根据虚拟机类型构建命令
    $command = '';
    
    if ($vmType === 'nat') {
        $sshPort = $params['sshPort'];
        $httpPort = $params['httpPort'];
        $httpsPort = $params['httpsPort'];
        
        $command = SCRIPTS_DIR . "/buildvm.sh $vmid $username $password $cpu $memory $disk $sshPort $httpPort $httpsPort 50000 50025 $os $storage $ipv6Enabled";
    } elseif ($vmType === 'direct') {
        $ipAddress = $params['ipAddress'];
        $subnet = $params['subnet'] ?? '24';
        
        $command = SCRIPTS_DIR . "/buildvm_manual_ip.sh $vmid $username $password $cpu $memory $disk $os $storage $ipAddress/$subnet $ipv6Enabled";
    } elseif ($vmType === 'ipv6') {
        $command = SCRIPTS_DIR . "/buildvm_onlyv6.sh $vmid $username $password $cpu $memory $disk $os $storage";
    } else {
        throw new Exception('不支持的虚拟机类型');
    }
    
    // 执行命令
    $result = execCommand($command);
    
    if ($result['exit_code'] !== 0) {
        throw new Exception('创建虚拟机失败: ' . $result['output']);
    }
    
    // 返回结果
    return [
        'vmid' => (int)$vmid,
        'output' => $result['output']
    ];
}

/**
 * 启动虚拟机
 */
function startVM($vmid) {
    $command = "qm start $vmid";
    $result = execCommand($command);
    
    if ($result['exit_code'] !== 0) {
        throw new Exception('启动虚拟机失败: ' . $result['output']);
    }
    
    return [
        'vmid' => (int)$vmid,
        'output' => $result['output']
    ];
}

/**
 * 停止虚拟机
 */
function stopVM($vmid) {
    $command = "qm stop $vmid";
    $result = execCommand($command);
    
    if ($result['exit_code'] !== 0) {
        throw new Exception('停止虚拟机失败: ' . $result['output']);
    }
    
    return [
        'vmid' => (int)$vmid,
        'output' => $result['output']
    ];
}

/**
 * 删除虚拟机
 */
function deleteVM($vmid) {
    $command = SCRIPTS_DIR . "/pve_delete.sh $vmid";
    $result = execCommand($command);
    
    if ($result['exit_code'] !== 0) {
        throw new Exception('删除虚拟机失败: ' . $result['output']);
    }
    
    return [
        'vmid' => (int)$vmid,
        'output' => $result['output']
    ];
}

/**
 * 获取网络接口列表
 */
function getNetworkInterfaces() {
    $command = "ip -o addr show";
    $result = execCommand($command);
    
    if ($result['exit_code'] !== 0) {
        throw new Exception('获取网络接口失败: ' . $result['output']);
    }
    
    $lines = explode("\n", $result['output']);
    $interfaces = [];
    
    foreach ($lines as $line) {
        if (empty(trim($line))) continue;
        
        // 解析接口信息
        if (preg_match('/^\d+:\s+(\w+)\s+(.+)/', $line, $matches)) {
            $name = $matches[1];
            $info = $matches[2];
            
            // 跳过lo接口
            if ($name === 'lo') continue;
            
            // 查找现有接口
            $interfaceExists = false;
            foreach ($interfaces as &$iface) {
                if ($iface['name'] === $name) {
                    $interfaceExists = true;
                    
                    // 添加IPv4或IPv6地址
                    if (preg_match('/inet\s+([^\/]+\/\d+)/', $info, $ipMatches)) {
                        $iface['ipv4'] = $ipMatches[1];
                    }
                    
                    if (preg_match('/inet6\s+([^\/]+\/\d+)/', $info, $ip6Matches)) {
                        $iface['ipv6'] = $ip6Matches[1];
                    }
                    
                    break;
                }
            }
            
            // 如果接口不存在，创建新接口
            if (!$interfaceExists) {
                $type = 'unknown';
                $status = 'down';
                $ipv4 = '';
                $ipv6 = '';
                $mac = '';
                
                // 确定接口类型
                if (strpos($name, 'vmbr') === 0) {
                    if ($name === 'vmbr0') {
                        $type = '桥接网卡';
                    } elseif ($name === 'vmbr1') {
                        $type = 'NAT网桥';
                    } elseif ($name === 'vmbr2') {
                        $type = 'IPv6网桥';
                    } else {
                        $type = '桥接网卡';
                    }
                } elseif (strpos($name, 'eth') === 0 || strpos($name, 'en') === 0) {
                    $type = '物理网卡';
                }
                
                // 检测接口状态
                if (strpos($info, 'UP') !== false) {
                    $status = 'up';
                }
                
                // 获取IP地址
                if (preg_match('/inet\s+([^\/]+\/\d+)/', $info, $ipMatches)) {
                    $ipv4 = $ipMatches[1];
                }
                
                if (preg_match('/inet6\s+([^\/]+\/\d+)/', $info, $ip6Matches)) {
                    $ipv6 = $ip6Matches[1];
                }
                
                // 获取MAC地址
                if (preg_match('/link\/ether\s+([0-9a-f:]+)/i', $info, $macMatches)) {
                    $mac = $macMatches[1];
                }
                
                $interfaces[] = [
                    'name' => $name,
                    'type' => $type,
                    'status' => $status,
                    'ipv4' => $ipv4,
                    'ipv6' => $ipv6,
                    'mac' => $mac
                ];
            }
        }
    }
    
    return $interfaces;
}

/**
 * 获取端口映射列表
 */
function getPortForwards() {
    $command = "iptables -t nat -L PREROUTING -n | grep DNAT";
    $result = execCommand($command);
    
    // 如果命令失败，但可能是因为没有任何转发规则
    if ($result['exit_code'] !== 0 && empty($result['output'])) {
        return [];
    }
    
    if ($result['exit_code'] !== 0) {
        throw new Exception('获取端口映射失败: ' . $result['output']);
    }
    
    $lines = explode("\n", $result['output']);
    $portForwards = [];
    
    foreach ($lines as $line) {
        if (empty(trim($line))) continue;
        
        // 解析端口映射规则
        if (preg_match('/(\w+)\s+.*dpt:(\d+).*to:([0-9.]+):(\d+)/', $line, $matches)) {
            $protocol = strtolower($matches[1]);
            $externalPort = (int)$matches[2];
            $internalIP = $matches[3];
            $internalPort = (int)$matches[4];
            
            $portForwards[] = [
                'extPort' => $externalPort,
                'protocol' => $protocol,
                'intIP' => $internalIP,
                'intPort' => $internalPort
            ];
        }
    }
    
    return $portForwards;
}

/**
 * 添加端口映射
 */
function addPortForward($params) {
    $externalPort = $params['externalPort'];
    $internalIP = $params['internalIP'];
    $internalPort = $params['internalPort'];
    $protocol = $params['protocol'];
    
    $command = SCRIPTS_DIR . "/network_manager.sh port_forward $externalPort $internalIP $internalPort $protocol";
    $result = execCommand($command);
    
    if ($result['exit_code'] !== 0) {
        throw new Exception('添加端口映射失败: ' . $result['output']);
    }
    
    return [
        'extPort' => (int)$externalPort,
        'intIP' => $internalIP,
        'intPort' => (int)$internalPort,
        'protocol' => $protocol
    ];
}

/**
 * 删除端口映射
 */
function deletePortForward($port, $protocol) {
    $command = SCRIPTS_DIR . "/network_manager.sh delete_port_forward $port $protocol";
    $result = execCommand($command);
    
    if ($result['exit_code'] !== 0) {
        throw new Exception('删除端口映射失败: ' . $result['output']);
    }
    
    return [
        'port' => (int)$port,
        'protocol' => $protocol
    ];
}

/**
 * 获取IPv6信息
 */
function getIPv6Info() {
    // 检查IPv6子网
    $subnetCommand = "ip -6 addr show dev vmbr0 2>/dev/null | grep -oP '(?<=inet6\s)[\da-f]+:[\da-f:]+(?=/64)'";
    $subnetResult = execCommand($subnetCommand);
    $subnet = trim($subnetResult['output']);
    
    // 如果子网命令失败，尝试其他接口
    if (empty($subnet)) {
        $mainIfaceCommand = "ip route | grep default | awk '{print \$5}'";
        $mainIfaceResult = execCommand($mainIfaceCommand);
        $mainIface = trim($mainIfaceResult['output']);
        
        if (!empty($mainIface)) {
            $subnetCommand = "ip -6 addr show dev $mainIface 2>/dev/null | grep -oP '(?<=inet6\s)[\da-f]+:[\da-f:]+(?=/64)'";
            $subnetResult = execCommand($subnetCommand);
            $subnet = trim($subnetResult['output']);
        }
    }
    
    // IPv6网关
    $gateway = '';
    if (!empty($subnet)) {
        $gateway = $subnet . '::1';
    }
    
    // 检查IPv6是否启用
    $enabled = !empty($subnet);
    
    return [
        'subnet' => $subnet ? $subnet . '/64' : '',
        'gateway' => $gateway,
        'enabled' => $enabled
    ];
}

/**
 * 备份系统配置
 */
function backupSystem() {
    $backupDir = '/root/pve_backup_' . date('YmdHis');
    $command = SCRIPTS_DIR . "/utils.sh backup_system_config $backupDir";
    $result = execCommand($command);
    
    if ($result['exit_code'] !== 0) {
        throw new Exception('备份系统配置失败: ' . $result['output']);
    }
    
    return [
        'backupDir' => $backupDir,
        'output' => $result['output']
    ];
}

/**
 * 恢复系统配置
 */
function restoreSystem($backupPath) {
    if (!file_exists($backupPath)) {
        throw new Exception('备份目录不存在: ' . $backupPath);
    }
    
    $command = SCRIPTS_DIR . "/utils.sh restore_system_config $backupPath";
    $result = execCommand($command);
    
    if ($result['exit_code'] !== 0) {
        throw new Exception('恢复系统配置失败: ' . $result['output']);
    }
    
    return [
        'backupPath' => $backupPath,
        'output' => $result['output']
    ];
}

/**
 * 检查系统更新
 */
function checkUpdates() {
    $command = "apt-get update && apt-get upgrade -s | grep -c ^Inst";
    $result = execCommand($command);
    
    if ($result['exit_code'] !== 0) {
        throw new Exception('检查更新失败: ' . $result['output']);
    }
    
    $updates = (int)trim($result['output']);
    
    return [
        'updates' => $updates,
        'hasUpdates' => $updates > 0
    ];
}

/**
 * 重启系统
 */
function restartSystem() {
    // 使用后台执行，避免阻塞API请求
    $command = "nohup bash -c 'sleep 3 && reboot' > /dev/null 2>&1 &";
    $result = execCommand($command);
    
    return [
        'status' => 'restarting'
    ];
} 