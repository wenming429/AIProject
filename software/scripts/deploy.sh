#!/bin/bash
#===============================================================================
# LumenIM 自动化部署脚本 - 本地构建部分
# 使用说明: 在有网络的开发机器上执行此脚本
#===============================================================================

set -e

# 配置参数
DEPLOY_HOST="192.168.23.129"
DEPLOY_USER="root"
DEPLOY_PORT="22"
DEPLOY_PASSWORD="123456"

# LumenIM 安装目录
REMOTE_DEPLOY_DIR="/opt/lumenim"
REMOTE_BACKEND_DIR="${REMOTE_DEPLOY_DIR}/backend"
REMOTE_FRONTEND_DIR="${REMOTE_DEPLOY_DIR}/frontend"
REMOTE_CONFIG_DIR="${REMOTE_DEPLOY_DIR}/config"

# 本地临时目录
LOCAL_BUILD_DIR="/tmp/lumenim-build-$(date +%Y%m%d%H%M%S)"
LOCAL_PACKAGE="${LOCAL_BUILD_DIR}/lumenim-package.tar.gz"

# 项目路径
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

#===============================================================================
# 步骤 1: 环境检查
#===============================================================================
check_environment() {
    log_info "========== 步骤 1: 环境检查 =========="

    # 检查构建工具
    local missing_tools=()

    command -v go >/dev/null 2>&1 || missing_tools+=("go")
    command -v node >/dev/null 2>&1 || missing_tools+=("node")
    command -v pnpm >/dev/null 2>&1 || missing_tools+=("pnpm")
    command -v ssh >/dev/null 2>&1 || missing_tools+=("ssh")
    command -v scp >/dev/null 2>&1 || missing_tools+=("scp")
    command -v tar >/dev/null 2>&1 || missing_tools+=("tar")

    if [ ${#missing_tools[@]} -gt 0 ]; then
        log_error "缺少必要的工具: ${missing_tools[*]}"
        log_info "请安装以下工具后重试:"
        for tool in "${missing_tools[@]}"; do
            case $tool in
                go)    echo "  - Go: https://go.dev/dl/" ;;
                node)  echo "  - Node.js: https://nodejs.org/" ;;
                pnpm)  echo "  - pnpm: npm install -g pnpm" ;;
                ssh)   echo "  - openssh-clients: yum install openssh-clients" ;;
            esac
        done
        exit 1
    fi

    # 检查 Go 版本
    GO_VERSION=$(go version | grep -oP 'go\d+\.\d+' | head -1)
    log_info "Go 版本: $(go version)"
    log_info "Node 版本: $(node --version)"
    log_info "pnpm 版本: $(pnpm --version)"

    # 检查项目目录
    if [ ! -d "${PROJECT_ROOT}/backend" ] || [ ! -d "${PROJECT_ROOT}/frontend" ]; then
        log_error "项目目录结构不正确，请确认 backend 和 frontend 目录存在"
        exit 1
    fi

    log_info "环境检查通过 ✓"
}

#===============================================================================
# 步骤 2: 清理旧构建
#===============================================================================
cleanup_old_builds() {
    log_info "========== 步骤 2: 清理旧构建 =========="

    # 清理旧的构建目录
    rm -rf "${LOCAL_BUILD_DIR}"
    mkdir -p "${LOCAL_BUILD_DIR}"

    # 清理旧的包文件
    rm -f /tmp/lumenim-package-*.tar.gz

    log_info "旧构建清理完成 ✓"
}

#===============================================================================
# 步骤 3: 构建后端
#===============================================================================
build_backend() {
    log_info "========== 步骤 3: 构建后端 =========="

    cd "${PROJECT_ROOT}/backend"

    # 下载 Go 依赖
    log_info "下载 Go 依赖..."
    go mod download

    # 打包 vendor（用于离线重新编译）
    log_info "打包 Go vendor..."
    go mod vendor

    # 交叉编译 Linux amd64 版本
    log_info "交叉编译后端 (Linux amd64)..."
    CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build \
        -ldflags="-s -w" \
        -o lumenim \
        ./cmd/lumenim

    # 检查二进制文件
    if [ ! -f "./lumenim" ]; then
        log_error "后端构建失败，未生成 lumenim 二进制文件"
        exit 1
    fi

    log_info "后端构建成功 ✓"
    log_info "二进制文件大小: $(ls -lh ./lumenim | awk '{print $5}')"
}

#===============================================================================
# 步骤 4: 构建前端
#===============================================================================
build_frontend() {
    log_info "========== 步骤 4: 构建前端 =========="

    cd "${PROJECT_ROOT}/frontend"

    # 安装前端依赖
    log_info "安装前端依赖..."
    pnpm install --frozen-lockfile

    # 构建前端
    log_info "构建前端..."
    pnpm build --mode production

    # 检查构建产物
    if [ ! -d "./dist" ]; then
        log_error "前端构建失败，未生成 dist 目录"
        exit 1
    fi

    log_info "前端构建成功 ✓"
    log_info "构建产物大小: $(du -sh ./dist | cut -f1)"
}

#===============================================================================
# 步骤 5: 打包部署文件
#===============================================================================
package_deployment() {
    log_info "========== 步骤 5: 打包部署文件 =========="

    cd "${LOCAL_BUILD_DIR}"

    # 创建目录结构
    mkdir -p backend frontend config sql

    # 复制后端文件
    log_info "打包后端文件..."
    cp "${PROJECT_ROOT}/backend/lumenim" ./backend/
    cp "${PROJECT_ROOT}/backend/config.yaml" ./config/ 2>/dev/null || true
    cp -r "${PROJECT_ROOT}/backend/sql" ./sql/
    cp "${PROJECT_ROOT}/backend/go.mod" ./backend/
    cp "${PROJECT_ROOT}/backend/go.sum" ./backend/

    # 复制前端构建产物
    log_info "打包前端文件..."
    cp -r "${PROJECT_ROOT}/frontend/dist" ./frontend/

    # 创建部署信息文件
    cat > ./deploy-info.txt << EOF
LumenIM 自动化部署包
构建时间: $(date '+%Y-%m-%d %H:%M:%S')
构建主机: $(hostname)
Go 版本: $(go version)
Node 版本: $(node --version)
前端构建模式: production
后端架构: linux/amd64
EOF

    # 打包
    log_info "创建部署包..."
    tar -czf "${LOCAL_PACKAGE}" ./*
    rm -rf ./backend ./frontend ./config ./sql

    log_info "部署包创建完成 ✓"
    log_info "包路径: ${LOCAL_PACKAGE}"
    log_info "包大小: $(ls -lh "${LOCAL_PACKAGE}" | awk '{print $5}')"
}

#===============================================================================
# 步骤 6: 传输文件到远程服务器
#===============================================================================
transfer_files() {
    log_info "========== 步骤 6: 传输文件到远程服务器 =========="

    # 检查 SSH 连接
    log_info "检查 SSH 连接..."
    if ! sshpass -p "${DEPLOY_PASSWORD}" ssh -o StrictHostKeyChecking=no \
        -o ConnectTimeout=10 ${DEPLOY_USER}@${DEPLOY_HOST} "echo ok" 2>/dev/null; then
        log_error "无法连接到远程服务器 ${DEPLOY_HOST}"
        log_info "请检查:"
        echo "  1. 服务器 IP 是否正确: ${DEPLOY_HOST}"
        echo "  2. SSH 服务是否运行"
        echo "  3. 用户名密码是否正确"
        exit 1
    fi

    # 创建远程目录
    log_info "创建远程部署目录..."
    sshpass -p "${DEPLOY_PASSWORD}" ssh ${DEPLOY_USER}@${DEPLOY_HOST} "
        mkdir -p ${REMOTE_DEPLOY_DIR}
        mkdir -p ${REMOTE_BACKEND_DIR}
        mkdir -p ${REMOTE_FRONTEND_DIR}
        mkdir -p ${REMOTE_CONFIG_DIR}
        echo '远程目录创建完成'
    "

    # 传输部署包
    log_info "传输部署包到远程服务器..."
    sshpass -p "${DEPLOY_PASSWORD}" scp -o StrictHostKeyChecking=no \
        "${LOCAL_PACKAGE}" ${DEPLOY_USER}@${DEPLOY_HOST}:/tmp/

    # 传输到远程服务器并解压
    log_info "解压部署包..."
    sshpass -p "${DEPLOY_PASSWORD}" ssh ${DEPLOY_USER}@${DEPLOY_HOST} "
        cd ${REMOTE_DEPLOY_DIR}
        tar -xzf /tmp/lumenim-package-*.tar.gz --overwrite
        chmod +x backend/lumenim
        echo '部署包解压完成'
    "

    # 清理临时文件
    rm -rf "${LOCAL_BUILD_DIR}"

    log_info "文件传输完成 ✓"
}

#===============================================================================
# 步骤 7: 执行远程部署
#===============================================================================
remote_deploy() {
    log_info "========== 步骤 7: 执行远程部署 =========="

    sshpass -p "${DEPLOY_PASSWORD}" ssh ${DEPLOY_USER}@${DEPLOY_HOST} << 'REMOTE_SCRIPT'
set -e

DEPLOY_DIR="/opt/lumenim"
BACKEND_DIR="${DEPLOY_DIR}/backend"
FRONTEND_DIR="${DEPLOY_DIR}/frontend"

echo "=========================================="
echo "LumenIM 远程部署脚本"
echo "部署时间: $(date '+%Y-%m-%d %H:%M:%S')"
echo "=========================================="

# 1. 检查 Docker 服务
echo "[1/8] 检查 Docker 服务..."
if ! systemctl is-active --quiet docker; then
    echo "  Docker 服务未启动，正在启动..."
    systemctl start docker
    systemctl enable docker
fi
echo "  Docker 版本: $(docker --version)"

# 2. 加载 Docker 镜像（如有）
echo "[2/8] 加载 Docker 镜像..."
if [ -f "${DEPLOY_DIR}/images/mysql-8.0.35.tar" ]; then
    docker load -i "${DEPLOY_DIR}/images/mysql-8.0.35.tar" 2>/dev/null || true
fi
if [ -f "${DEPLOY_DIR}/images/redis-7.4.1.tar" ]; then
    docker load -i "${DEPLOY_DIR}/images/redis-7.4.1.tar" 2>/dev/null || true
fi
echo "  Docker 镜像列表:"
docker images | grep -E "mysql|redis" || echo "  暂无相关镜像"

# 3. 启动 MySQL 容器
echo "[3/8] 启动 MySQL 容器..."
if docker ps -a | grep -q lumenim-mysql; then
    if docker ps | grep -q lumenim-mysql; then
        echo "  MySQL 容器已在运行"
    else
        docker start lumenim-mysql
        echo "  MySQL 容器已启动"
    fi
else
    docker run -d \
        --name lumenim-mysql \
        -e MYSQL_ROOT_PASSWORD=wenming429 \
        -e MYSQL_DATABASE=go_chat \
        -e MYSQL_USER=lumenim \
        -e MYSQL_PASSWORD=lumenim123 \
        -p 3306:3306 \
        -v /var/lib/lumenim/mysql:/var/lib/mysql \
        mysql:8.0.35 \
        --default-authentication-plugin=mysql_native_password
    echo "  MySQL 容器创建并启动成功"
fi

# 4. 启动 Redis 容器
echo "[4/8] 启动 Redis 容器..."
if docker ps -a | grep -q lumenim-redis; then
    if docker ps | grep -q lumenim-redis; then
        echo "  Redis 容器已在运行"
    else
        docker start lumenim-redis
        echo "  Redis 容器已启动"
    fi
else
    docker run -d \
        --name lumenim-redis \
        -p 6379:6379 \
        -v /var/lib/lumenim/redis:/data \
        redis:7.4.1 redis-server --appendonly yes
    echo "  Redis 容器创建并启动成功"
fi

# 5. 配置后端
echo "[5/8] 配置后端服务..."
cat > ${BACKEND_DIR}/config.yaml << 'CONFIG'
app:
  env: production
  port: 9501
  shutdown_timeout: 10

mysql:
  host: 127.0.0.1
  port: 3306
  username: root
  password: wenming429
  database: go_chat
  max_open_conns: 100
  max_idle_conns: 10

redis:
  host: 127.0.0.1
  port: 6379
  database: 0
  pool_size: 100

minio:
  endpoint: 127.0.0.1:9000
  access_key: minioadmin
  secret_key: minioadmin
  use_ssl: false
  bucket: lumenim

im:
  heartbeat: 30s
  max_connect: 10000
CONFIG
echo "  配置文件已创建"

# 6. 创建 systemd 服务
echo "[6/8] 创建 systemd 服务..."
cat > /etc/systemd/system/lumenim-backend.service << 'SERVICE'
[Unit]
Description=LumenIM Backend Service
After=network.target docker.service

[Service]
Type=simple
User=root
WorkingDirectory=/opt/lumenim/backend
ExecStart=/opt/lumenim/backend/lumenim
Restart=on-failure
RestartSec=5s
LimitNOFILE=65536
Environment="PATH=/usr/local/go/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

[Install]
WantedBy=multi-user.target
SERVICE

systemctl daemon-reload
echo "  systemd 服务已创建"

# 7. 启动后端服务
echo "[7/8] 启动后端服务..."
systemctl enable lumenim-backend
systemctl restart lumenim-backend

# 8. 等待服务启动
echo "[8/8] 等待服务启动并检查健康状态..."
sleep 5

# 检查服务状态
echo ""
echo "=========================================="
echo "服务状态检查"
echo "=========================================="
echo ""
echo "Docker 容器:"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
echo ""
echo "后端服务:"
systemctl status lumenim-backend --no-pager || true
echo ""
echo "端口监听:"
netstat -tlnp | grep -E "9501|9502|3306|6379" || ss -tlnp | grep -E "9501|9502|3306|6379" || true
echo ""
echo "后端健康检查:"
curl -s http://localhost:9501/api/v1/health 2>/dev/null || echo "  健康检查端点暂无响应"

echo ""
echo "=========================================="
echo "部署完成!"
echo "=========================================="
REMOTE_SCRIPT

    log_info "远程部署执行完成 ✓"
}

#===============================================================================
# 步骤 8: 健康检查
#===============================================================================
health_check() {
    log_info "========== 步骤 8: 健康检查 =========="

    # 等待服务完全启动
    sleep 10

    # 检查各个服务
    log_info "检查 Docker 容器..."
    sshpass -p "${DEPLOY_PASSWORD}" ssh ${DEPLOY_USER}@${DEPLOY_HOST} "
        echo 'Docker 容器状态:'
        docker ps --format '  {{.Names}}: {{.Status}}'
        echo ''
        echo 'MySQL 连接测试:'
        docker exec lumenim-mysql mysql -u root -pwenming429 -e 'SELECT 1 AS test;' 2>/dev/null && echo '  MySQL 连接成功 ✓' || echo '  MySQL 连接失败 ✗'
        echo ''
        echo 'Redis 连接测试:'
        docker exec lumenim-redis redis-cli ping 2>/dev/null && echo '  Redis 连接成功 ✓' || echo '  Redis 连接失败 ✗'
    "

    log_info "检查后端服务..."
    sshpass -p "${DEPLOY_PASSWORD}" ssh ${DEPLOY_USER}@${DEPLOY_HOST} "
        echo '后端服务状态:'
        systemctl is-active lumenim-backend
        echo ''
        echo '健康检查:'
        curl -s http://localhost:9501/api/v1/health 2>/dev/null || echo '  后端暂无响应'
        echo ''
        echo '端口监听状态:'
        ss -tlnp | grep -E '9501|9502|3306|6379' 2>/dev/null || netstat -tlnp | grep -E '9501|9502|3306|6379' 2>/dev/null || echo '  端口检查完成'
    "

    log_info "=========================================="
    log_info "部署完成！"
    log_info "=========================================="
    log_info "访问地址: http://${DEPLOY_HOST}:9501"
    log_info "管理后台: http://${DEPLOY_HOST}:9501/admin"
    log_info "前端地址: http://${DEPLOY_HOST}:5173 (如需开发模式)"
    log_info ""
    log_info "服务管理命令:"
    echo "  登录服务器: ssh ${DEPLOY_USER}@${DEPLOY_HOST}"
    echo "  查看后端日志: journalctl -u lumenim-backend -f"
    echo "  重启后端: systemctl restart lumenim-backend"
    echo "  查看 Docker 日志: docker logs -f lumenim-mysql"
}

#===============================================================================
# 主函数
#===============================================================================
main() {
    echo ""
    echo "=============================================="
    echo "  LumenIM 自动化部署脚本"
    echo "  目标服务器: ${DEPLOY_HOST}"
    echo "  部署目录: ${REMOTE_DEPLOY_DIR}"
    echo "=============================================="
    echo ""

    # 检查 sshpass
    if ! command -v sshpass >/dev/null 2>&1; then
        log_warn "缺少 sshpass 工具，将尝试安装..."
        if command -v apt-get >/dev/null 2>&1; then
            sudo apt-get install -y sshpass
        elif command -v yum >/dev/null 2>&1; then
            sudo yum install -y sshpass
        elif command -v brew >/dev/null 2>&1; then
            brew install sshpass
        else
            log_error "无法自动安装 sshpass，请手动安装后重试"
            exit 1
        fi
    fi

    # 执行部署步骤
    check_environment
    cleanup_old_builds
    build_backend
    build_frontend
    package_deployment
    transfer_files
    remote_deploy
    health_check
}

# 运行
main "$@"
