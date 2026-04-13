# CentOS 7 系统依赖离线部署指南

**文档版本**: 1.0.1  
**更新日期**: 2026-04-08  
**适用场景**: Windows 下载 → CentOS 7 断网部署

---

## 一、系统依赖包清单

### 1.1 必需系统包（Base 仓库）

| 软件包 | 说明 | 必要性 |
|--------|------|--------|
| wget | 下载工具 | 必须 |
| curl | HTTP 客户端 | 必须 |
| git | 版本控制 | 必须 |
| unzip | ZIP 解压 | 必须 |
| tar | TAR 解压 | 必须 |
| xz | XZ 解压 | 必须 |
| gcc | C 编译器 | 必须 |
| gcc-c++ | C++ 编译器 | 必须 |
| make | 构建工具 | 必须 |
| openssl | SSL 库 | 必须 |
| perl | 脚本语言 | 可选 |
| net-tools | 网络工具 | 可选 |

### 1.2 EPEL 仓库

| 软件包 | 说明 | 必要性 |
|--------|------|--------|
| epel-release | EPEL 源 | 必须 |
| jq | JSON 处理 | 可选 |
| htop | 进程监控 | 可选 |
| iotop | IO 监控 | 可选 |

---

## 二、Windows 环境下载方案

### 方案一：使用 CentOS 7 ISO（推荐）

#### 2.1.1 下载 CentOS 7 ISO

```powershell
# 官方下载（选择 DVD ISO）
# 访问: https://www.centos.org/centos-download/
# 建议下载: CentOS-7-x86_64-DVD-2009.iso (约 4.5GB)
```

#### 2.1.2 制作本地 YUM 源

从 ISO 提取 RPM 包：

```powershell
# 使用 7-Zip 或 WinRAR 解压 ISO
# 将解压后的 packages 目录内容复制到服务器

# 服务器端配置
mount -o loop /path/to/CentOS-7-x86_64-DVD-2009.iso /mnt/iso

# 创建 local.repo
cat > /etc/yum.repos.d/local.repo << 'EOF'
[local]
name=Local Media
baseurl=file:///mnt/iso
enabled=1
gpgcheck=0
EOF

# 清除缓存
yum clean all
yum repolist
```

---

### 方案二：下载 RPM 包（更复杂）

#### 2.2.1 使用 GitHub Actions 或虚拟机

在 **有网络的 Linux 虚拟机** 中下载：

```bash
#!/bin/bash
# download-rpms.sh

OUTPUT_DIR="/tmp/centos7-rpms"
mkdir -p "$OUTPUT_DIR"

# Base 仓库包（使用 vault.centos.org）
BASE_URL="https://vault.centos.org/7.9.2009/os/x86_64/Packages"

packages=(
    "wget-1.14-18.el7_9.1.x86_64.rpm"
    "curl-7.61.1-9.el7.x86_64.rpm"
    "git-1.8.3.1-23.el7_9.x86_64.rpm"
    "unzip-6.0-24.el7.x86_64.rpm"
    "tar-1.27-17.el7.x86_64.rpm"
    "xz-5.2.2-2.el7.x86_64.rpm"
    "gcc-4.8.5-44.el7.x86_64.rpm"
    "gcc-c++-4.8.5-44.el7.x86_64.rpm"
    "make-3.82-29.el7.x86_64.rpm"
    "openssl-1.0.2k-25.el7.x86_64.rpm"
    "perl-5.16.3-299.el7_9.2.x86_64.rpm"
    "net-tools-2.0-0.0.20161004git.el7.x86_64.rpm"
    "glibc-2.17-317.el7.x86_64.rpm"
    "glibc-common-2.17-317.el7.x86_64.rpm"
    "glibc-devel-2.17-317.el7.x86_64.rpm"
    "libstdc++-4.8.5-44.el7.x86_64.rpm"
    "libstdc++-devel-4.8.5-44.el7.x86_64.rpm"
    "kernel-headers-3.10.0-1160.el7.x86_64.rpm"
)

for pkg in "${packages[@]}"; do
    echo "下载: $pkg"
    wget -O "$OUTPUT_DIR/$pkg" "$BASE_URL/$pkg" || echo "失败: $pkg"
done

# EPEL 包
EPEL_URL="https://dl.fedoraproject.org/pub/epel/7/x86_64/Packages"
epel_packages=(
    "epel-release-7-14.noarch.rpm"
    "jq-1.6-2.el7.x86_64.rpm"
)

for pkg in "${epel_packages[@]}"; do
    echo "下载 EPEL: $pkg"
    wget -O "$OUTPUT_DIR/$pkg" "$EPEL_URL/$pkg" || echo "失败: $pkg"
done

echo "完成，共 $(ls $OUTPUT_DIR | wc -l) 个文件"
```

---

### 方案三：使用 Docker 容器（最佳方案）

对于无法访问外网的 CentOS 7，推荐使用 **Docker 部署方案**：

```bash
# 服务器已有 Docker（即使无网络）
# 从 Windows 传�� Docker 镜像

# 1. 在有 Docker 的机器上导出
docker save -o mysql-8.0.35.tar mysql:8.0.35
docker save -o redis-7.4.1.tar redis:7.4.1

# 2. 传输到目标服务器
scp mysql-8.0.35.tar user@server:/tmp/
scp redis-7.4.1.tar user@server:/tmp/

# 3. 目标服务器加载
docker load -i mysql-8.0.35.tar
docker load -i redis-7.4.1.tar
```

---

## 三、传输到服务器

### 3.1 U 盘方式

```powershell
# Windows 复制到 U 盘
Copy-Item -Path "D:\LumenIM-Packages\*" -Destination "E:\" -Recurse
Copy-Item -Path "C:\Software\CentOS-7-x86_64-DVD-2009.iso" -Destination "E:\"
```

### 3.2 服务器挂载

```bash
# 查看设备
lsblk

# 挂载 U 盘
mount /dev/sdc1 /mnt/packages

# 验证
ls -la /mnt/packages
```

---

## 四、服务器端安装

### 4.1 方式一：本地 YUM 源

```bash
# 挂载 ISO
mount -o loop /mnt/packages/CentOS-7-x86_64-DVD-2009.iso /mnt/iso

# 配置本地源
cat > /etc/yum.repos.d/local.repo << 'EOF'
[LocalBase]
name=CentOS 7 Local
baseurl=file:///mnt/iso
enabled=1
gpgcheck=0

[EPEL]
name=Extra Packages
baseurl=file:///mnt/iso
enabled=0
EOF

# 安装依赖（自动解决依赖）
yum clean all
yum repolist

# 安装系统包
yum install -y wget curl git unzip tar xz gcc gcc-c++ make openssl net-tools

# 安装开发工具（如果需要）
yum install -y gcc gcc-c++ make
```

### 4.2 方式二：手动 RPM 安装

```bash
# 进入离线包目录
cd /mnt/packages/rpms

# 强制安装
rpm -Uvh --force *.rpm

# 或使用 yum 本地安装（自动解决依赖）
yum localinstall *.rpm
```

### 4.3 方式三：Docker 部署（推荐）

对于断网环境，**Docker 容器方案**最简单：

```bash
# 1. 安装 Docker（rpm 方式）
cd /mnt/packages/docker
yum localinstall *.rpm

# 2. 启动 Docker
systemctl start docker
systemctl enable docker

# 3. 加载 MySQL 镜像
docker load -i /mnt/packages/mysql-8.0.35.tar

# 4. 加载 Redis 镜像
docker load -i /mnt/packages/redis-7.4.1.tar

# 5. 运行 MySQL
docker run -d \
    --name lumenim-mysql \
    -e MYSQL_ROOT_PASSWORD=wenming429 \
    -e MYSQL_DATABASE=lumenim \
    -p 3306:3306 \
    mysql:8.0.35

# 6. 运行 Redis
docker run -d \
    --name lumenim-redis \
    -p 6379:6379 \
    redis:7.4.1

# 7. 验证
docker ps
docker exec -it lumenim-mysql mysql -uroot -pwenming429 -e "SHOW DATABASES;"
```

---

## 五、验证安装

### 5.1 系统包验证

```bash
# 检查已安装的包
rpm -qa | grep -E "wget|curl|git|gcc"

# 或
yum list installed | grep -E "wget|curl|git|gcc"
```

### 5.2 服务验证

```bash
# Docker 方式
docker ps
docker images

# MySQL 测试
docker exec -it lumenim-mysql mysql -uroot -pwenming429 -e "SELECT VERSION();"

# Redis 测试
docker exec -it lumenim-redis redis-cli ping
```

---

## 六、完整部署流程汇总

### 步骤一：Windows 准备

| 序号 | 操作 | 输出 |
|------|------|------|
| 1 | 下载 LumenIM 离线包 | `D:\LumenIM-Packages\` |
| 2 | 下载 CentOS 7 ISO | `CentOS-7-x86_64-DVD-2009.iso` |
| 3 | 导出 Docker 镜像 | `mysql-8.0.35.tar`, `redis-7.4.1.tar` |
| 4 | 复制到 U 盘 | - |

### 步骤二：服务器部署

```bash
# 1. 挂载 U 盘
mount /dev/sdc1 /mnt/packages

# 2. 安装 Docker
cd /mnt/packages/docker
yum localinstall containerd.io-*.rpm docker-ce-*.rpm docker-ce-cli-*.rpm

# 3. 启动 Docker
systemctl start docker
systemctl enable docker

# 4. 加载镜像
docker load -i /mnt/packages/mysql-8.0.35.tar
docker load -i /mnt/packages/redis-7.4.1.tar

# 5. 安装 Go（如果需要本地编译）
cd /
tar -xzf /mnt/packages/go1.21.13.linux-amd64.tar.gz

# 6. 安装 Node.js
cd /
tar -xJf /mnt/packages/node-v18.20.5-linux-x64.tar.xz
mv node-v18.20.5-linux-x64 /usr/local/node
```

---

## 七、常见问题

### Q1: RPM 安装依赖错误

```bash
# 错误：Failed dependencies
# 解决：使用 yum localinstall 自动解决依赖
yum localinstall /mnt/packages/*.rpm
```

### Q2: Docker 无法启动

```bash
# 检查日志
journalctl -xe -u docker

# 或
dockerd --debug
```

### Q3: 镜像加载失败

```bash
# 检查镜像文件
file mysql-8.0.35.tar

# 重新加载
docker load -i mysql-8.0.35.tar
```

---

*文档版本: 1.0.1*