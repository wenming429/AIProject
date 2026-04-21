# LumenIM 服务器网络故障诊断报告

**文档编号**: INC-20260410-001  
**问题类型**: DNS 解析故障  
**影响范围**: 外网访问、Docker 镜像拉取、apt 包更新  
**状态**: ✅ 已解决  
**负责人**: DevOps Team  
**创建日期**: 2026-04-10  
**解决日期**: 2026-04-10  

---

## 一、环境背景

### 1.1 网络架构

```
┌─────────────────────────────────────────────────────────────┐
│                      宿主机 (Windows)                        │
│                   物理网络: 192.168.0.0/24                  │
│                        DNS: 192.168.0.1                      │
│                            │                                 │
│                     虚拟网卡桥接                             │
└────────────────────────────┼─────────────────────────────────┘
                             │
┌────────────────────────────┼─────────────────────────────────┐
│                    Ubuntu 虚拟机                             │
│                 虚拟网络: 192.168.23.0/24                   │
│              IP 地址: 192.168.23.131 (ens33)                 │
│              网关: 192.168.23.2                             │
│              DNS: 127.0.0.53 (错误配置)                      │
└─────────────────────────────────────────────────────────────┘
```

### 1.2 服务器配置

| 项目 | 配置信息 |
|------|----------|
| 操作系统 | Ubuntu 20.04 LTS |
| 主机名 | lumenimserver |
| IP 地址 | 192.168.23.131 |
| 子网掩码 | 255.255.255.0 (/24) |
| 默认网关 | 192.168.23.2 |
| 虚拟化平台 | VMware / VirtualBox |
| 宿主机 DNS | 192.168.0.1 |

### 1.3 问题现象

- ✅ 网关连通性正常 (`ping 192.168.23.2` 成功)
- ✅ 外网 IP 连通性正常 (`ping 8.8.8.8` 成功)
- ❌ 域名解析失败 (`nslookup www.baidu.com` 失败)
- ❌ 无法访问外网网站
- ❌ Docker 无法拉取镜像
- ❌ apt 无法更新软件包

---

## 二、排查步骤

### 2.1 排查流程图

```
┌─────────────────┐
│  测试基本连通性   │
└────────┬────────┘
         │
         ▼
┌─────────────────┐     否      ┌─────────────────┐
│  ping 网关成功?  │ ─────────► │   检查网段配置   │
└────────┬────────┘             └─────────────────┘
         │ 是
         ▼
┌─────────────────┐     否      ┌─────────────────┐
│  ping 8.8.8.8   │ ─────────► │   检查路由表     │
│     成功?       │             └─────────────────┘
└────────┬────────┘
         │ 是
         ▼
┌─────────────────┐     否      ┌─────────────────┐
│  ping 外网域名   │ ─────────► │   检查DNS配置    │ ◄── 问题点
│     成功?       │             └─────────────────┘
└────────┬────────┘
         │ 是
         ▼
    ┌─────────┐
    │  网络正常 │
    └─────────┘
```

### 2.2 详细排查步骤

#### 步骤 1：检查网络接口状态

```bash
wenming429@lumenimserver:~$ ip addr show | grep inet
    inet 127.0.0.1/8 scope host lo
    inet 192.168.23.131/24 brd 192.168.23.255 scope global dynamic ens33
```

**结果分析**: ✅ 网卡配置正确，获取到 192.168.23.131/24 地址

---

#### 步骤 2：检查路由表

```bash
wenming429@lumenimserver:~$ ip route show
default via 192.168.23.2 dev ens33 proto dhcp src 192.168.23.131 metric 100
192.168.23.0/24 dev ens33 proto kernel scope link src 192.168.23.131
```

**结果分析**: ✅ 默认网关配置正确

---

#### 步骤 3：测试网关连通性

```bash
wenming429@lumenimserver:~$ ping -c 1 -W 2 192.168.23.2
PING 192.168.23.2 (192.168.23.2) 56(84) bytes of data.
64 bytes from 192.168.23.2: icmp_seq=1 ttl=64 time=0.295 ms

--- 192.168.23.2 ping statistics ---
1 packets transmitted, 1 received, 0% packet loss
```

**结果分析**: ✅ 网关可达

---

#### 步骤 4：测试外网 IP 连通性

```bash
wenming429@lumenimserver:~$ ping -c 1 -W 2 8.8.8.8
PING 8.8.8.8 (8.8.8.8) 56(84) bytes of data.
64 bytes from 8.8.8.8: icmp_seq=1 ttl=114 time=9.57 ms

--- 8.8.8.8 ping statistics ---
1 packets transmitted, 1 received, 0% packet loss
```

**结果分析**: ✅ 可以访问外网 IP（路由正常）

---

#### 步骤 5：测试 DNS 解析

```bash
wenming429@lumenimserver:~$ nslookup www.baidu.com
** server can't find www.baidu.com: SERVFAIL

wenming429@lumenimserver:~$ ping www.baidu.com
ping: www.baidu.com: Temporary failure in name resolution
```

**结果分析**: ❌ **DNS 解析失败**（问题定位）

---

#### 步骤 6：检查 DNS 配置文件

```bash
wenming429@lumenimserver:~$ cat /etc/resolv.conf
nameserver 127.0.0.53
options edns0 trust-ad
search localdomain
```

**结果分析**: ❌ **DNS 服务器指向本地 systemd-resolved (127.0.0.53)，但该服务未能正确转发 DNS 查询**

---

## 三、根因分析

### 3.1 问题根因

| 层级 | 配置项 | 错误配置 | 正确配置 |
|------|--------|----------|----------|
| DNS | `/etc/resolv.conf` | `nameserver 127.0.0.53` | `nameserver 192.168.0.1` |
| systemd | `resolved.conf` | 未配置上游 DNS | `DNS=192.168.0.1` |

### 3.2 问题机理

```
用户请求: www.baidu.com
         ↓
本地 DNS 缓存服务 systemd-resolved (127.0.0.53)
         ↓
尝试向上游 DNS 服务器转发查询
         ↓
上游 DNS 未配置或配置错误
         ↓
DNS 解析失败
         ↓
域名无法解析为 IP 地址
         ↓
所有依赖域名解析的服务无法工作
```

### 3.3 影响范围评估

| 受影响服务 | 影响程度 | 说明 |
|-----------|----------|------|
| apt 包管理器 | 🔴 严重 | 无法更新软件包 |
| Docker | 🔴 严重 | 无法拉取镜像 |
| curl/wget | 🔴 严重 | 无法访问外部资源 |
| 浏览器/应用 | 🔴 严重 | 无法访问外网服务 |
| NTP 时间同步 | 🟡 中等 | 可能影响时间准确性 |

---

## 四、解决方案

### 4.1 修复步骤

#### 第一步：配置 systemd-resolved

```bash
# 创建 systemd-resolved 配置文件
sudo tee /etc/systemd/resolved.conf <<'EOF'
[Resolve]
DNS=192.168.0.1
FallbackDNS=223.5.5.5 119.29.29.29
DNSStubListener=yes
EOF
```

#### 第二步：更新 resolv.conf

```bash
# 移除旧链接/文件
sudo rm -f /etc/resolv.conf

# 创建新的 DNS 配置
echo "nameserver 192.168.0.1" | sudo tee /etc/resolv.conf
```

#### 第三步：重启 DNS 服务

```bash
# 重启 systemd-resolved
sudo systemctl restart systemd-resolved

# 验证服务状态
sudo systemctl status systemd-resolved
```

#### 第四步：验证修复

```bash
# 测试 DNS 解析
nslookup www.baidu.com

# 测试网络连通性
ping -c 3 www.baidu.com

# 测试相关服务
curl -I https://www.baidu.com
sudo apt update
docker pull hello-world
```

### 4.2 一键修复脚本

```bash
#!/bin/bash
# fix_dns_for_vm.sh - 虚拟机 DNS 修复脚本

set -e

echo "=========================================="
echo "  LumenIM 虚拟机 DNS 修复脚本"
echo "=========================================="
echo ""

# 配置 DNS 服务器（宿主机 IP）
PRIMARY_DNS="192.168.0.1"
FALLBACK_DNS="223.5.5.5 119.29.29.29"

echo "[1/4] 配置 systemd-resolved..."
sudo tee /etc/systemd/resolved.conf > /dev/null <<EOF
[Resolve]
DNS=${PRIMARY_DNS}
FallbackDNS=${FALLBACK_DNS}
DNSStubListener=yes
EOF

echo "[2/4] 更新 /etc/resolv.conf..."
sudo rm -f /etc/resolv.conf
echo "nameserver ${PRIMARY_DNS}" | sudo tee /etc/resolv.conf > /dev/null

echo "[3/4] 重启 systemd-resolved 服务..."
sudo systemctl restart systemd-resolved

echo "[4/4] 验证修复结果..."
echo ""
echo "DNS 配置:"
cat /etc/resolv.conf
echo ""

# 执行验证测试
echo "执行测试:"
if nslookup www.baidu.com > /dev/null 2>&1; then
    echo "  ✅ DNS 解析: 成功"
else
    echo "  ❌ DNS 解析: 失败"
fi

if ping -c 1 -W 2 www.baidu.com > /dev/null 2>&1; then
    echo "  ✅ 网络连通: 成功"
else
    echo "  ❌ 网络连通: 失败"
fi

if curl -s --connect-timeout 5 https://www.baidu.com > /dev/null 2>&1; then
    echo "  ✅ HTTPS 访问: 成功"
else
    echo "  ⚠️  HTTPS 访问: 需手动测试"
fi

echo ""
echo "=========================================="
echo "  修复完成!"
echo "=========================================="
```

### 4.3 修复验证清单

| 测试项 | 命令 | 预期结果 |
|--------|------|----------|
| DNS 解析 | `nslookup www.baidu.com` | 返回 IP 地址 |
| ICMP 连通 | `ping -c 3 www.baidu.com` | 无丢包 |
| HTTP 访问 | `curl -I https://www.baidu.com` | HTTP 200 |
| HTTPS 访问 | `curl -I https://registry-1.docker.io` | HTTP 200 |
| apt 更新 | `sudo apt update` | 获取软件包列表 |
| Docker 测试 | `docker pull hello-world` | 镜像拉取成功 |

---

## 五、预防措施

### 5.1 静态 DNS 配置

为防止 DNS 配置被覆盖，创建一个永久配置：

```bash
# 方法一：锁定 resolv.conf
sudo chattr +i /etc/resolv.conf

# 解锁（如需修改）
sudo chattr -i /etc/resolv.conf

# 方法二：配置 DHCP 不修改 DNS
sudo nano /etc/dhcp/dhclient.conf
# 添加或修改:
supersede domain-name-servers 192.168.0.1;

# 方法三：创建 NetworkManager 配置
sudo tee /etc/NetworkManager/conf.d/dns.conf <<EOF
[main]
dns=none
systemd-resolved=no
EOF
```

### 5.2 虚拟机组网建议

| 虚拟化平台 | 推荐网络模式 | DNS 配置说明 |
|-----------|-------------|-------------|
| VMware | 桥接模式 (Bridged) | 使用宿主机 DNS |
| VMware | NAT 模式 | 使用 VMware DHCP DNS |
| VirtualBox | 桥接模式 | 使用宿主机 DNS |
| VirtualBox | NAT 模式 | 使用 VirtualBox DHCP DNS |

**推荐配置**：
```bash
# 编辑网络接口配置
sudo nano /etc/netplan/00-installer-config.yaml
```

```yaml
network:
  version: 2
  renderer: networkd
  ethernets:
    ens33:
      addresses:
        - 192.168.23.131/24
      gateway4: 192.168.23.2
      nameservers:
        addresses:
          - 192.168.0.1          # 宿主机 DNS
          - 223.5.5.5            # 阿里云 DNS (备用)
          - 119.29.29.29         # 腾讯 DNS (备用)
        search: []
      dhcp4: false
```

```bash
# 应用配置
sudo netplan apply

# 验证
netplan ip leases ens33
cat /etc/resolv.conf
```

### 5.3 监控告警配置

创建网络健康检查脚本：

```bash
#!/bin/bash
# network_health_check.sh - 网络健康检查脚本

LOG_FILE="/var/log/network_health.log"
ALERT_EMAIL="admin@example.com"

check_dns() {
    if ! nslookup www.baidu.com > /dev/null 2>&1; then
        echo "[$(date)] DNS 故障" >> $LOG_FILE
        # 发送告警 (需配置邮件服务)
        # echo "DNS 故障" | mail -s "网络告警" $ALERT_EMAIL
        return 1
    fi
    return 0
}

check_gateway() {
    if ! ping -c 1 -W 2 192.168.23.2 > /dev/null 2>&1; then
        echo "[$(date)] 网关故障" >> $LOG_FILE
        return 1
    fi
    return 0
}

# 执行检查
check_gateway
check_dns

# 记录成功
echo "[$(date)] 网络健康" >> $LOG_FILE
```

### 5.4 标准化部署检查清单

在部署 LumenIM 或其他服务前，确保以下检查项全部通过：

```bash
# ===== 网络检查清单 =====
echo "===== LumenIM 部署前网络检查 ====="

check_result() {
    if [ $1 -eq 0 ]; then
        echo "  [✅] $2"
    else
        echo "  [❌] $2"
        FAILED=$((FAILED + 1))
    fi
}

FAILED=0

check_result $(ping -c 1 -W 2 192.168.23.2 > /dev/null 2>&1 && echo 0 || echo 1) "网关连通性"
check_result $(ping -c 1 -W 2 8.8.8.8 > /dev/null 2>&1 && echo 0 || echo 1) "外网连通性"
check_result $(nslookup www.baidu.com > /dev/null 2>&1 && echo 0 || echo 1) "DNS 解析"
check_result $(curl -s --connect-timeout 5 https://www.baidu.com > /dev/null 2>&1 && echo 0 || echo 1) "HTTPS 访问"
check_result $(docker --version > /dev/null 2>&1 && echo 0 || echo 1) "Docker 安装"
check_result $(sudo apt update > /dev/null 2>&1 && echo 0 || echo 1) "apt 源访问"

echo ""
if [ $FAILED -eq 0 ]; then
    echo "所有检查通过，可以进行部署!"
else
    echo "有 $FAILED 项检查失败，请修复后再部署"
fi
```

### 5.5 文档维护

| 维护项 | 周期 | 说明 |
|--------|------|------|
| 网络配置文档 | 每季度 | 更新网络架构和配置信息 |
| 故障记录 | 实时 | 记录每次故障和处理过程 |
| 应急预案 | 每半年 | 更新应急响应流程 |
| 监控配置 | 每月 | 检查监控告警有效性 |

---

## 六、附录

### 附录 A：关键命令速查

| 功能 | 命令 |
|------|------|
| 查看 DNS 配置 | `cat /etc/resolv.conf` |
| 查看 systemd-resolved 状态 | `systemd-resolve --status` |
| 测试 DNS 解析 | `nslookup <domain>` 或 `dig <domain>` |
| 测试网络连通 | `ping <IP/域名>` |
| 查看路由表 | `ip route show` |
| 查看网卡状态 | `ip addr show` |
| 测试 HTTP 访问 | `curl -I <url>` |
| 重启 DNS 服务 | `sudo systemctl restart systemd-resolved` |

### 附录 B：常见 DNS 服务器

| 提供商 | 主 DNS | 备用 DNS |
|--------|-------|----------|
| 阿里云 | 223.5.5.5 | 223.6.6.6 |
| 腾讯云 | 119.29.29.29 | 182.254.116.116 |
| Google | 8.8.8.8 | 8.8.4.4 |
| Cloudflare | 1.1.1.1 | 1.0.0.1 |

### 附录 C：相关配置文件路径

```
/etc/resolv.conf              # DNS 解析配置文件
/etc/systemd/resolved.conf     # systemd-resolved 配置
/etc/netplan/*.yaml          # 网络配置 (Ubuntu 17.10+)
/etc/network/interfaces      # 传统网络配置
/etc/dhcp/dhclient.conf       # DHCP 客户端配置
/etc/NetworkManager/         # NetworkManager 配置
```

---

## 七、变更记录

| 日期 | 版本 | 变更内容 | 作者 |
|------|------|----------|------|
| 2026-04-10 | 1.0 | 初始故障报告 | DevOps Team |
| 2026-04-10 | 1.1 | 补充预防措施 | DevOps Team |

---

**文档结束**
