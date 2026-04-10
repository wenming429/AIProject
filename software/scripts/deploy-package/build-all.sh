#!/bin/bash
#===============================================================================
# LumenIM 完整部署包打包脚本
# 功能：同时打包前后端部署文件
# 使用：bash build-all.sh
#===============================================================================

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PKG_DIR="$SCRIPT_DIR/deploy-package"

echo -e "${BLUE}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║        LumenIM 完整部署包打包工具              ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════╝${NC}"

# 清理旧包
echo -e "\n${YELLOW}[清理] 清理旧的部署包...${NC}"
rm -f "$PKG_DIR"/*.tar.gz
rm -rf "$PKG_DIR/front" "$PKG_DIR/backend"

# 打包前端
echo -e "\n${GREEN}>>> 打包前端部署包...${NC}"
bash "$SCRIPT_DIR/build-frontend.sh"

# 打包后端
echo -e "\n${GREEN}>>> 打包后端部署包...${NC}"
bash "$SCRIPT_DIR/build-backend.sh"

# 创建完整部署包
echo -e "\n${YELLOW}[整合] 创建完整部署包...${NC}"

# 复制 docker-compose 配置
mkdir -p "$PKG_DIR/docker"
if [ -f "$SCRIPT_DIR/docker-compose-ubuntu.yaml" ]; then
    cp "$SCRIPT_DIR/docker-compose-ubuntu.yaml" "$PKG_DIR/docker/docker-compose.yaml"
fi

# 创建完整部署包
cd "$PKG_DIR"
tar -czvf "lumenim-full-$(date +%Y%m%d-%H%M%S).tar.gz" \
    front/ \
    backend/ \
    docker/ \
    2>/dev/null || true

# 统计
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}   部署包打包完成！${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${YELLOW}生成的文件:${NC}"
ls -lh "$PKG_DIR"/*.tar.gz 2>/dev/null || true
echo ""

# 目录结构预览
echo -e "${YELLOW}完整部署包结构预览:${NC}"
echo ""
echo "deploy-package/"
echo "├── lumenim-full-*.tar.gz    # 完整部署包"
echo "├── lumenim-front-*.tar.gz    # 前端部署包"
echo "├── lumenim-backend-*.tar.gz  # 后端部署包"
echo "│"
echo "├── front/                   # 前端部署目录"
echo "│   ├── dist/                # 前端构建产物"
echo "│   └── config/              # 配置文件"
echo "│"
echo "├── backend/                 # 后端部署目录"
echo "│   ├── lumenim             # 可执行文件"
echo "│   ├── sql/                # 数据库脚本"
echo "│   ├── uploads/            # 上传目录"
echo "│   ├── runtime/            # 运行时目录"
echo "│   └── config/             # 配置文件"
echo "│"
echo "└── docker/                  # Docker 配置"
echo "    └── docker-compose.yaml  # Docker 编排文件"
echo ""
