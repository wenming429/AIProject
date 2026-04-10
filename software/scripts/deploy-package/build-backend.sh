#!/bin/bash
#===============================================================================
# LumenIM 后端部署包打包脚本
# 功能：构建后端并打包部署文件
# 使用：bash build-backend.sh
#===============================================================================

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 项目根目录
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PKG_DIR="$SCRIPT_DIR/deploy-package"

# 目录结构
BACKEND_DIR="$PKG_DIR/backend"
BACKEND_SRC="$PROJECT_ROOT/backend"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}   LumenIM 后端部署包打包工具${NC}"
echo -e "${GREEN}========================================${NC}"

# 清理函数
cleanup() {
    echo -e "\n${YELLOW}[清理] 删除临时构建目录...${NC}"
    rm -rf "$PKG_DIR/temp"
}

# 错误处理
error_exit() {
    echo -e "\n${RED}[错误] $1${NC}" >&2
    cleanup
    exit 1
}

# 创建目录结构
create_dirs() {
    echo -e "\n${YELLOW}[步骤 1/6] 创建部署包目录结构...${NC}"
    
    mkdir -p "$BACKEND_DIR"
    mkdir -p "$BACKEND_DIR/sql"
    mkdir -p "$BACKEND_DIR/uploads/images"
    mkdir -p "$BACKEND_DIR/uploads/files"
    mkdir -p "$BACKEND_DIR/uploads/avatars"
    mkdir -p "$BACKEND_DIR/uploads/audio"
    mkdir -p "$BACKEND_DIR/uploads/video"
    mkdir -p "$BACKEND_DIR/runtime/logs"
    mkdir -p "$BACKEND_DIR/runtime/cache"
    mkdir -p "$BACKEND_DIR/runtime/temp"
    mkdir -p "$BACKEND_DIR/config"
    mkdir -p "$PKG_DIR/temp"
    
    echo -e "${GREEN}✓ 目录创建完成${NC}"
}

# 检查依赖
check_dependencies() {
    echo -e "\n${YELLOW}[步骤 2/6] 检查构建依赖...${NC}"
    
    # 检查 Go
    if ! command -v go &> /dev/null; then
        echo -e "${RED}错误: 未安装 Go${NC}"
        echo "请安装 Go 1.21+: https://go.dev/dl/"
        exit 1
    fi
    
    echo -e "${GREEN}✓ Go 版本: $(go version)${NC}"
}

# 构建后端 (Linux amd64)
build_backend() {
    echo -e "\n${YELLOW}[步骤 3/6] 构建后端 (Linux amd64)...${NC}"
    
    if [ ! -d "$BACKEND_SRC" ]; then
        error_exit "后端源码目录不存在: $BACKEND_SRC"
    fi
    
    cd "$BACKEND_SRC"
    
    # 设置交叉编译环境
    export CGO_ENABLED=0
    export GOOS=linux
    export GOARCH=amd64
    export GOPROXY=https://goproxy.cn,direct
    
    # 执行构建
    echo "编译后端服务..."
    go build -ldflags="-s -w" -o lumenim ./cmd/lumenim
    
    if [ ! -f "lumenim" ]; then
        error_exit "构建失败: 可执行文件未生成"
    fi
    
    # 复制可执行文件
    cp lumenim "$BACKEND_DIR/"
    
    echo -e "${GREEN}✓ 后端构建完成${NC}"
    echo "  文件: lumenim ($(du -h "$BACKEND_DIR/lumenim" | cut -f1))"
}

# 复制数据库脚本
copy_sql() {
    echo -e "\n${YELLOW}[步骤 4/6] 复制数据库脚本...${NC}"
    
    # 查找 SQL 文件
    if [ -f "$BACKEND_SRC/data/sql/lumenim.sql" ]; then
        cp "$BACKEND_SRC/data/sql/lumenim.sql" "$BACKEND_DIR/sql/"
    elif [ -f "$BACKEND_SRC/sql/lumenim.sql" ]; then
        cp "$BACKEND_SRC/sql/lumenim.sql" "$BACKEND_DIR/sql/"
    else
        echo -e "${YELLOW}警告: 未找到数据库脚本${NC}"
    fi
    
    echo -e "${GREEN}✓ 数据库脚本已复制${NC}"
}

# 创建配置文件
create_configs() {
    echo -e "\n${YELLOW}[步骤 5/6] 创建配置文件...${NC}"
    
    # config.yaml 示例
    cat > "$BACKEND_DIR/config/config.yaml.example" <<'EOF'
# ==================== 应用配置 ====================
app:
  env: prod                           # 环境: dev/test/prod
  debug: false                         # 调试模式
  admin_email:
    - admin@yourcompany.com
  public_key: |                        # RSA 公钥
    -----BEGIN PUBLIC KEY-----
    MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA...
    -----END PUBLIC KEY-----
  private_key: |                       # RSA 私钥
    -----BEGIN PRIVATE KEY-----
    MIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSj...
    -----END PRIVATE KEY-----
  aes_key: "32位随机字符串用于AES加密"

# ==================== 服务端口 ====================
server:
  http_addr: ":9501"                   # HTTP API 端口
  websocket_addr: ":9502"              # WebSocket 端口
  tcp_addr: ":9505"                    # TCP 端口 (预留)

# ==================== 日志配置 ====================
log:
  path: "./runtime/logs"
  level: "info"
  max_size: 100
  max_backups: 30
  max_age: 7

# ==================== Redis 配置 ====================
redis:
  host: 127.0.0.1
  port: 6379
  auth: "your_redis_password"
  database: 0
  pool_size: 100

# ==================== MySQL 配置 ====================
mysql:
  host: 127.0.0.1
  port: 3306
  username: root
  password: "your_mysql_password"
  database: go_chat
  charset: utf8mb4
  max_open_conns: 100
  max_idle_conns: 10

# ==================== JWT 配置 ====================
jwt:
  secret: "your_jwt_secret_key_32chars"
  expires_time: 86400
  buffer_time: 86400

# ==================== 跨域配置 ====================
cors:
  origin: "https://your-domain.com"
  headers: "Content-Type,Cache-Control,User-Agent,AccessToken,Authorization"
  methods: "OPTIONS,GET,POST,PUT,DELETE"
  credentials: true
  max_age: 600

# ==================== 文件存储配置 ====================
filesystem:
  default: local                       # 存储驱动: local/minio
  local:
    root: "./uploads"
    bucket_public: "public"
    bucket_private: "private"
  minio:
    secret_id: "minioadmin"
    secret_key: "your_minio_password"
    bucket_public: "im-static"
    bucket_private: "im-private"
    endpoint: "127.0.0.1:9000"
    ssl: false

# ==================== 邮件配置 (可选) ====================
email:
  host: smtp.ym.163.com
  port: 465
  username: noreply@yourcompany.com
  password: "smtp_password"
  fromname: "LumenIM"
EOF

    # .env 示例
    cat > "$BACKEND_DIR/config/.env.example" <<'EOF'
# ==================== 数据库配置 ====================
MYSQL_HOST=127.0.0.1
MYSQL_PORT=3306
MYSQL_DATABASE=go_chat
MYSQL_USER=root
MYSQL_PASSWORD=your_mysql_password

# ==================== Redis 配置 ====================
REDIS_HOST=127.0.0.1
REDIS_PORT=6379
REDIS_PASSWORD=your_redis_password

# ==================== MinIO 配置 ====================
MINIO_ENDPOINT=127.0.0.1:9000
MINIO_ROOT_USER=minioadmin
MINIO_ROOT_PASSWORD=your_minio_password

# ==================== 应用配置 ====================
APP_ENV=production
APP_DEBUG=false
BIND_IP=0.0.0.0
EOF

    # 部署说明
    cat > "$BACKEND_DIR/config/README.md" <<'EOF'
# 后端部署配置说明

## 目录结构

```
backend/
├── lumenim                    # Go 可执行文件 (Linux amd64)
├── config.yaml                # 主配置文件
│
├── sql/                       # 数据库脚本
│   └── lumenim.sql            # 数据库初始化SQL
│
├── uploads/                   # 用户上传目录
│   ├── images/                # 聊天图片
│   ├── files/                 # 文件传输
│   ├── audio/                 # 语音消息
│   ├── video/                 # 视频消息
│   └── avatars/               # 用户头像
│
├── runtime/                   # 运行时目录
│   ├── logs/                  # 日志文件
│   ├── cache/                 # 缓存文件
│   └── temp/                  # 临时文件
│
└── config/                    # 配置文件备份
    ├── config.yaml.example
    └── .env.example
```

## 服务说明

| 服务 | 命令 | 端口 | 说明 |
|------|------|------|------|
| HTTP API | `./lumenim http` | 9501 | RESTful API 服务 |
| WebSocket | `./lumenim comet` | 9502 | 实时消息长连接 |
| Queue | `./lumenim queue` | - | 异步任务处理 |
| Cron | `./lumenim crontab` | - | 定时任务执行 |

## 部署步骤

### 1. 配置数据库

```bash
# 登录 MySQL
mysql -u root -p

# 创建数据库
CREATE DATABASE go_chat CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

# 执行初始化脚本
source lumenim.sql
```

### 2. 配置 Redis

```bash
# 编辑 Redis 配置
vim /etc/redis/redis.conf

# 添加密码认证
requirepass your_redis_password
```

### 3. 配置后端

```bash
# 复制配置示例
cp config/config.yaml.example config.yaml
cp config/.env.example .env

# 编辑配置
vim config.yaml
```

### 4. 设置权限

```bash
# 设置可执行权限
chmod +x lumenim

# 设置运行时目录权限
chown -R 1000:1000 runtime/
chown -R 1000:1000 uploads/

# 设置配置文件权限
chmod 600 config.yaml
```

### 5. 启动服务

```bash
# 启动 HTTP API 服务
./lumenim http --config=config.yaml &

# 启动 WebSocket 服务
./lumenim comet --config=config.yaml &

# 启动队列服务
./lumenim queue --config=config.yaml &

# 启动定时任务服务
./lumenim crontab --config=config.yaml &
```

## 使用 systemd 管理服务

创建服务文件 `/etc/systemd/system/lumenim-http.service`:

```ini
[Unit]
Description=LumenIM HTTP Service
After=network.target mysql.service redis.service

[Service]
Type=simple
User=root
WorkingDirectory=/opt/lumenim/backend
ExecStart=/opt/lumenim/backend/lumenim http --config=/opt/lumenim/backend/config.yaml
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```

```bash
# 启用服务
sudo systemctl enable lumenim-http
sudo systemctl start lumenim-http
```
EOF

    echo -e "${GREEN}✓ 配置文件已创建${NC}"
}

# 打包
create_package() {
    echo -e "\n${YELLOW}[步骤 6/6] 创建部署包...${NC}"
    
    cd "$PKG_DIR"
    
    PACKAGE_NAME="lumenim-backend-$(date +%Y%m%d-%H%M%S).tar.gz"
    
    tar -czvf "$PACKAGE_NAME" backend/
    
    echo -e "\n${GREEN}========================================${NC}"
    echo -e "${GREEN}   后端部署包打包完成！${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo -e "\n部署包位置: $PKG_DIR/$PACKAGE_NAME"
    echo -e "大小: $(du -h "$PACKAGE_NAME" | cut -f1)"
    echo ""
    echo -e "后端部署包内容:"
    echo -e "  ├── lumenim           # Go 可执行文件"
    echo -e "  ├── sql/              # 数据库脚本"
    echo -e "  ├── uploads/          # 上传目录 (需创建)"
    echo -e "  ├── runtime/          # 运行时目录 (需创建)"
    echo -e "  └── config/           # 配置文件"
    echo ""
}

# 主流程
main() {
    trap cleanup EXIT
    
    create_dirs
    check_dependencies
    build_backend
    copy_sql
    create_configs
    create_package
    
    echo -e "\n${GREEN}打包成功！请查看 $PKG_DIR 目录${NC}"
}

main "$@"
