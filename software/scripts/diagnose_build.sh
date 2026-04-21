#!/bin/bash
#
# Go 后端构建诊断脚本
# 用于排查"所有Go文件被排除"的构建问题
#
# 使用方法: sudo ./diagnose_build.sh
#

set -e

echo "========================================"
echo "  Go 后端构建诊断"
echo "========================================"

# 设置 Go 代理
export GOPROXY=https://goproxy.cn,direct
export GOSUMDB=off

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# ============================================
# 函数: 查找 Go 可执行文件
# ============================================
find_go_binary() {
    local go_paths=(
        "/usr/local/go/bin/go"
        "/usr/go/bin/go"
        "/usr/bin/go"
        "/usr/local/bin/go"
        "$HOME/go/bin/go"
    )

    for path in "${go_paths[@]}"; do
        if [ -x "$path" ]; then
            echo "$path"
            return 0
        fi
    done

    if command -v go &>/dev/null; then
        command -v go
        return 0
    fi

    return 1
}

# ============================================
# 函数: 查找 backend 目录
# ============================================
find_backend_dir() {
    local script_dir="$(cd "$(dirname "$0")" && pwd)"
    local possible_paths=(
        "$script_dir/../../backend"
        "$script_dir/../backend"
        "/var/www/lumenim/backend"
    )

    for path in "${possible_paths[@]}"; do
        if [ -d "$path" ] && [ -f "$path/go.mod" ]; then
            echo "$path"
            return 0
        fi
    done
    return 1
}

# ============================================
# 主程序
# ============================================

# 1. 检查 Go 安装
echo ""
echo "步骤 1: 检查 Go 安装..."
GO_BINARY="$(find_go_binary)" || {
    echo -e "${RED}错误: 找不到 Go 可执行文件！${NC}"
    exit 1
}
echo -e "${GREEN}找到 Go: $GO_BINARY${NC}"
"$GO_BINARY" version

# 2. 查找 backend 目录
echo ""
echo "步骤 2: 查找 backend 目录..."
BACKEND_DIR="$(find_backend_dir)" || {
    echo -e "${RED}错误: 找不到 backend 目录${NC}"
    exit 1
}
cd "$BACKEND_DIR"
echo -e "${GREEN}工作目录: $(pwd)${NC}"

# 3. 检查 go.mod
echo ""
echo "步骤 3: 检查 go.mod..."
if [ ! -f go.mod ]; then
    echo -e "${RED}错误: go.mod 文件不存在！${NC}"
    exit 1
fi

MODULE_NAME=$(grep "^module " go.mod | awk '{print $2}')
echo -e "${GREEN}模块名: $MODULE_NAME${NC}"

# 4. 检查构建约束语法
echo ""
echo "步骤 4: 检查构建约束语法..."
BUILD_ERRORS=0

# 查找所有构建约束
echo "检查以下文件中的构建约束:"

# 使用 find 查找所有 .go 文件
find . -name "*.go" -not -path "./vendor/*" | while read -r file; do
    # 检查是否包含构建约束
    if grep -q "^//go:build\|^// +build" "$file" 2>/dev/null; then
        echo "  检查: $file"
        # 检查格式是否正确
        FIRST_LINE=$(head -1 "$file")
        if [[ "$FIRST_LINE" =~ ^//go:build ]]; then
            # 检查是否有旧格式
            if grep -q "^// +build" "$file"; then
                # 检查两行之间是否空行
                LINE_COUNT=$(grep -n "^//go:build\|^// +build" "$file" | wc -l)
                if [ "$LINE_COUNT" -eq 2 ]; then
                    # 检查是否紧邻
                    LINE1=$(grep -n "^//go:build" "$file" | cut -d: -f1)
                    LINE2=$(grep -n "^// +build" "$file" | cut -d: -f1)
                    DIFF=$((LINE2 - LINE1))
                    if [ "$DIFF" -gt 1 ]; then
                        echo -e "    ${YELLOW}警告: 构建约束之间可能有空行${NC}"
                    fi
                fi
            fi
        fi
    fi
done

# 5. 检查文件名后缀
echo ""
echo "步骤 5: 检查文件名后缀..."
echo "查找可能存在平台限制的文件:"

find . -name "*_linux.go" -o -name "*_windows.go" -o -name "*_darwin.go" -o -name "*_amd64.go" -o -name "*_arm64.go" 2>/dev/null | while read -r file; do
    echo "  $file"
    # 检查该文件是否有对应的无条件版本
    BASENAME=$(basename "$file" | sed 's/_linux.go\|_windows.go\|_darwin.go\|_amd64.go\|_arm64.go/.go/')
    DIR=$(dirname "$file")
    if [ ! -f "$DIR/$BASENAME" ]; then
        echo -e "    ${YELLOW}警告: 没有找到对应的无条件文件，可能导致该平台编译失败${NC}"
        BUILD_ERRORS=$((BUILD_ERRORS + 1))
    fi
done

# 6. 检查 package 声明
echo ""
echo "步骤 6: 检查 package 声明..."
echo "主要包的 package 声明:"

# 检查 cmd/lumenim
if [ -f cmd/lumenim/main.go ]; then
    PKG=$(head -1 cmd/lumenim/main.go | tr -d '\r')
    echo "  cmd/lumenim/main.go: $PKG"
    if [[ "$PKG" != "package main" ]]; then
        echo -e "    ${YELLOW}注意: cmd/lumenim 应为 package main${NC}"
    fi
fi

# 7. 尝试列出将被编译的文件
echo ""
echo "步骤 7: 验证构建约束..."
echo "使用 go list 列出将被包含的文件:"

if "$GO_BINARY" list -f '{{.GoFiles}}' ./cmd/lumenim 2>&1; then
    echo -e "${GREEN}文件列表获取成功${NC}"
else
    echo -e "${YELLOW}go list 失败，尝试诊断...${NC}"
fi

# 8. 尝试诊断性构建
echo ""
echo "步骤 8: 执行诊断性构建..."
echo "运行: go build -n ./cmd/lumenim (仅检查，不实际编译)"

if "$GO_BINARY" build -n ./cmd/lumenim 2>&1 | head -50; then
    echo -e "${GREEN}诊断性构建检查完成${NC}"
else
    echo -e "${YELLOW}诊断性构建发现问题${NC}"
fi

# 9. 清理并重新下载依赖
echo ""
echo "步骤 9: 清理并重新下载依赖..."

read -p "是否清理模块缓存并重新下载依赖? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "清理模块缓存..."
    "$GO_BINARY" clean -modcache 2>/dev/null || true
    
    echo "重新下载依赖..."
    "$GO_BINARY" mod download
    
    echo "整理依赖..."
    "$GO_BINARY" mod tidy
    
    echo -e "${GREEN}依赖更新完成${NC}"
fi

# 10. 尝试完整构建
echo ""
echo "步骤 10: 尝试完整构建..."
echo "运行: CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o lumenim ./cmd/lumenim"

if CGO_ENABLED=0 GOOS=linux GOARCH=amd64 "$GO_BINARY" build -o lumenim ./cmd/lumenim 2>&1; then
    echo -e "${GREEN}构建成功！${NC}"
    ls -lh lumenim
else
    echo -e "${RED}构建失败！${NC}"
    echo ""
    echo "常见问题:"
    echo "  1. 检查是否有构建约束排除了所有文件"
    echo "  2. 确保 go.mod 中的 module 路径正确"
    echo "  3. 检查是否有文件名后缀(_linux.go等)导致文件被排除"
fi

echo ""
echo "========================================"
echo "  诊断完成"
echo "========================================"
