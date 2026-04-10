#!/bin/bash
#===============================================================================
# LumenIM 前端部署包打包脚本
# 功能：构建前端并打包部署文件
# 使用：bash build-frontend.sh
#===============================================================================

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 项目根目录
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PKG_DIR="$SCRIPT_DIR/deploy-package"

# 目录结构
FRONT_DIR="$PKG_DIR/front"
FRONT_SRC="$PROJECT_ROOT/front"
FRONT_DIST="$PKG_DIR/front/dist
FRONT_CONFIG="$PKG_DIR/front/config

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}   LumenIM 前端部署包打包工具${NC}"
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
    echo -e "\n${YELLOW}[步骤 1/4] 创建部署包目录结构...${NC}"
    
    mkdir -p "$FRONT_DIR/dist"
    mkdir -p "$FRONT_DIR/config"
    mkdir -p "$PKG_DIR/temp"
    
    echo -e "${GREEN}✓ 目录创建完成${NC}"
}

# 构建前端
build_frontend() {
    echo -e "\n${YELLOW}[步骤 2/4] 构建前端...${NC}"
    
    if [ ! -d "$FRONT_SRC" ]; then
        error_exit "前端源码目录不存在: $FRONT_SRC"
    fi
    
    cd "$FRONT_SRC"
    
    # 检查依赖
    if [ ! -d "node_modules" ]; then
        echo "安装依赖..."
        pnpm install --production
    fi
    
    # 执行构建
    echo "执行生产构建..."
    pnpm build
    
    # 复制构建产物
    echo "复制构建产物..."
    if [ -d "dist" ]; then
        cp -r dist/* "$FRONT_DIR/dist/"
    else
        error_exit "构建产物目录不存在"
    fi
    
    echo -e "${GREEN}✓ 前端构建完成${NC}"
}

# 复制配置文件
copy_configs() {
    echo -e "\n${YELLOW}[步骤 3/4] 复制配置文件...${NC}"
    
    # .env.production 配置示例
    cat > "$FRONT_CONFIG/.env.production.example" <<'EOF'
# ==================== 应用配置 ====================
ENV = 'production'
VITE_APP_NAME=LumenIM
VITE_APP_ENV=production

# ==================== 路由配置 ====================
VITE_BASE=/
VITE_ROUTER_MODE=history

# ==================== API 配置 ====================
# 请修改为你的服务器地址
VITE_BASE_API=https://your-domain.com/api
VITE_SOCKET_API=wss://your-domain.com/ws

# ==================== 安全配置 ====================
# RSA 公钥 (Base64编码)
VITE_RSA_PUBLIC_KEY="-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA...
-----END PUBLIC KEY-----"
EOF

    # Nginx 配置
    cat > "$FRONT_CONFIG/nginx.conf.example" <<'EOF'
# 前端 Nginx 配置
server {
    listen 80;
    server_name your-domain.com;
    
    # 根目录
    root /usr/share/nginx/html;
    index index.html;

    # ==================== 前端路由 (SPA) ====================
    location / {
        try_files $uri $uri/ /index.html;
    }

    # ==================== 静态资源缓存 ====================
    location ~* \.(gif|jpg|jpeg|png|bmp|swf|flv|ico)$ {
        expires 7d;
        access_log off;
        add_header Cache-Control "public, immutable";
    }

    location ~* \.(js|css|less|scss|sass)$ {
        expires 7d;
        access_log off;
        add_header Cache-Control "public, immutable";
    }

    location ~* \.(woff|woff2|ttf|eot|svg|otf)$ {
        expires 30d;
        access_log off;
        add_header Cache-Control "public";
    }

    # ==================== 健康检查 ====================
    location /health {
        access_log off;
        return 200 "OK";
        add_header Content-Type text/plain;
    }
}
EOF

    # 部署说明
    cat > "$FRONT_CONFIG/README.md" <<'EOF'
# 前端部署配置说明

## 目录结构

```
front/
├── dist/                      # 前端构建产物 (部署到 Nginx)
│   ├── index.html            # 入口页面
│   ├── embed.html            # 嵌入式页面
│   ├── favicon.ico           # 网站图标
│   └── assets/               # 静态资源
│       ├── *.js              # JavaScript 打包文件
│       ├── *.css             # CSS 样式文件
│       └── *.png/*.svg       # 图片资源
│
└── config/                    # 配置文件
    ├── .env.production.example
    └── nginx.conf.example
```

## 部署步骤

### 1. 修改环境配置

```bash
# 复制配置示例
cp .env.production.example .env.production

# 编辑配置
vim .env.production
```

修改以下配置项：
- `VITE_BASE_API` - 后端 API 地址
- `VITE_SOCKET_API` - WebSocket 地址
- `VITE_RSA_PUBLIC_KEY` - RSA 公钥

### 2. 重新构建 (如需修改配置)

```bash
cd front
pnpm build
```

### 3. 部署到服务器

```bash
# 上传到服务器
scp -r dist/* root@server:/usr/share/nginx/html/

# 或使用 Docker 卷挂载
```

## 资源缓存策略

| 资源类型 | 缓存时间 | 说明 |
|---------|---------|------|
| `.js` / `.css` | 7 天 | 含有 hash, 可长期缓存 |
| 图片 (`.png/.jpg`) | 7 天 | 含有 hash, 可长期缓存 |
| `index.html` | 不缓存 | 内容随时变化 |
| 字体文件 | 30 天 | 更新频率低 |
EOF

    echo -e "${GREEN}✓ 配置文件复制完成${NC}"
}

# 打包
create_package() {
    echo -e "\n${YELLOW}[步骤 4/4] 创建部署包...${NC}"
    
    cd "$PKG_DIR"
    
    PACKAGE_NAME="lumenim-front-$(date +%Y%m%d-%H%M%S).tar.gz"
    
    tar -czvf "$PACKAGE_NAME" front/
    
    echo -e "\n${GREEN}========================================${NC}"
    echo -e "${GREEN}   前端部署包打包完成！${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo -e "\n部署包位置: $PKG_DIR/$PACKAGE_NAME"
    echo -e "大小: $(du -h "$PACKAGE_NAME" | cut -f1)"
    echo ""
    echo -e "前端部署包内容:"
    echo -e "  ├── dist/           # 前端构建产物"
    echo -e "  └── config/         # 配置文件"
    echo ""
}

# 主流程
main() {
    trap cleanup EXIT
    
    create_dirs
    build_frontend
    copy_configs
    create_package
    
    echo -e "\n${GREEN}打包成功！请查看 $PKG_DIR 目录${NC}"
}

main "$@"
