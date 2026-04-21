#!/bin/bash
#
# Go 依赖修复/更新脚本
# 用于更新 Go 1.25+ 项目的依赖版本
#
# 使用方法: sudo ./fix_go_deps.sh
#

set -e

echo "========================================"
echo "  Go 依赖更新脚本 (Go 1.25+)"
echo "========================================"

# 设置 Go 代理
export GOPROXY=https://goproxy.cn,direct
export GOSUMDB=off
export GOTOOLCHAIN=local

# ============================================
# 函数: 查找 Go 可执行文件
# ============================================
find_go_binary() {
    local go_path=""
    local go_paths=(
        "/usr/local/go/bin/go"
        "/usr/go/bin/go"
        "/usr/bin/go"
        "/usr/local/bin/go"
        "$HOME/go/bin/go"
        "$HOME/.go/bin/go"
        "/opt/go/bin/go"
    )

    if command -v go &>/dev/null; then
        go_path="$(command -v go)"
        echo "$go_path"
        return 0
    fi

    for path in "${go_paths[@]}"; do
        if [ -x "$path" ]; then
            echo "$path"
            return 0
        fi
    done

    if command -v which &>/dev/null; then
        go_path="$(which go 2>/dev/null || true)"
        if [ -n "$go_path" ] && [ -x "$go_path" ]; then
            echo "$go_path"
            return 0
        fi
    fi

    return 1
}

# ============================================
# 函数: 获取 Go 环境变量
# ============================================
setup_go_env() {
    local go_bin_path=""

    go_bin_path="$(find_go_binary)" || {
        echo ""
        echo "错误: 找不到 Go 可执行文件！"
        echo ""
        echo "请先安装 Go 或将 Go 添加到 PATH 中。"
        echo ""
        echo "安装 Go 1.25:"
        echo "  wget https://go.dev/dl/go1.25.7.linux-amd64.tar.gz"
        echo "  sudo tar -C /usr/local -xzf go1.25.7.linux-amd64.tar.gz"
        echo "  echo 'export PATH=\$PATH:/usr/local/go/bin' >> ~/.bashrc"
        echo "  source ~/.bashrc"
        exit 1
    }

    GO_BINARY="$go_bin_path"
    GO_DIR="$(dirname "$(dirname "$GO_BINARY")")"
    export GOROOT="${GO_DIR}"
    export PATH="${GO_DIR}/bin:${PATH}"

    echo ""
    echo "Go 环境配置:"
    echo "  GO_BINARY: $GO_BINARY"
    echo "  GOROOT: $GOROOT"
    echo "  PATH: ${GO_DIR}/bin:..."
}

# ============================================
# 函数: 检查 Go 版本
# ============================================
check_go_version() {
    local min_major=1
    local min_minor=22
    local version_output
    local current_major=0
    local current_minor=0

    echo ""
    echo "检查 Go 版本..."

    version_output=$("$GO_BINARY" version 2>&1) || {
        echo "错误: 无法执行 go version"
        exit 1
    }

    echo "$version_output"

    if echo "$version_output" | grep -qE 'go([0-9]+)\.([0-9]+)'; then
        current_major=$(echo "$version_output" | grep -oE 'go([0-9]+)\.([0-9]+)' | grep -oE '[0-9]+\.[0-9]+' | cut -d. -f1)
        current_minor=$(echo "$version_output" | grep -oE 'go([0-9]+)\.([0-9]+)' | grep -oE '[0-9]+\.[0-9]+' | cut -d. -f2)
    fi

    echo ""
    echo "检测到版本: $current_major.$current_minor"

    # 对于 Go 1.25+，我们只需要确保版本足够新
    if [ "$current_major" -lt 1 ] || { [ "$current_major" -eq 1 ] && [ "$current_minor" -lt 22 ]; }; then
        echo "警告: 当前 Go 版本低于 1.22，建议升级到 Go 1.25+"
    fi
}

# ============================================
# 函数: 查找 backend 目录
# ============================================
find_backend_dir() {
    local script_dir="$(cd "$(dirname "$0")" && pwd)"
    local possible_paths=(
        "$script_dir/../../backend"
        "$script_dir/../backend"
        "$script_dir/../../../backend"
        "$script_dir/../../../../../backend"
        "/var/www/lumenim/backend"
    )

    for path in "${possible_paths[@]}"; do
        if [ -d "$path" ] && [ -f "$path/go.mod" ]; then
            echo "$path"
            return 0
        fi
    done

    echo "错误: 找不到包含 go.mod 的 backend 目录"
    exit 1
}

# ============================================
# 主程序
# ============================================

# 1. 配置 Go 环境
setup_go_env

# 2. 检查 Go 版本
check_go_version

# 3. 备份原始文件
echo ""
echo "备份原始 go.mod 和 go.sum..."

BACKEND_DIR="$(find_backend_dir)"
cd "$BACKEND_DIR"

echo "工作目录: $(pwd)"

if [ -f go.mod ]; then
    cp go.mod go.mod.backup
    echo "  已备份: go.mod -> go.mod.backup"
fi

if [ -f go.sum ]; then
    cp go.sum go.sum.backup
    echo "  已备份: go.sum -> go.sum.backup"
fi

# 4. 清理旧的不兼容 replace 规则
echo ""
echo "清理旧的不兼容配置..."

# 移除旧的 Go 1.22 兼容性 replace 规则
sed -i '/^replace ($/,/^)$/d' go.mod 2>/dev/null || true

# 移除重复的空行（如果有）
sed -i '/^$/N;/^\n$/d' go.mod 2>/dev/null || true

# 修复 filipio.io 拼写错误
sed -i 's/filipio\.io/filippo.io/g' go.mod
sed -i 's/filipio\.io/filippo.io/g' go.sum

echo "  已清理旧配置"

# 5. 重新生成依赖
echo ""
echo "重新生成依赖..."
"$GO_BINARY" mod tidy

# 6. 验证依赖
echo ""
echo "验证依赖..."
"$GO_BINARY" mod verify

echo ""
echo "========================================"
echo "  依赖更新完成！"
echo "========================================"
echo ""
echo "如果仍有问题，可以回滚："
echo "  cd $BACKEND_DIR"
echo "  mv go.mod.backup go.mod"
echo "  mv go.sum.backup go.sum"
