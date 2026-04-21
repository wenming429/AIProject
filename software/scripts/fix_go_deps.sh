#!/bin/bash
#
# Go 依赖修复脚本
# 用于解决 Go 1.22 环境下的依赖版本兼容问题
#
# 使用方法: sudo ./fix_go_deps.sh
#

set -e

echo "========================================"
echo "  Go 依赖修复脚本"
echo "========================================"

# 设置 Go 代理（即使 Go 不在 PATH 中也要设置）
export GOPROXY=https://goproxy.cn,direct
export GOSUMDB=off
export GOTOOLCHAIN=local

# ============================================
# 函数: 查找 Go 可执行文件
# ============================================
find_go_binary() {
    local go_path=""

    # 常见 Go 安装位置（按优先级排序）
    local go_paths=(
        "/usr/local/go/bin/go"
        "/usr/go/bin/go"
        "/usr/bin/go"
        "/usr/local/bin/go"
        "$HOME/go/bin/go"
        "$HOME/.go/bin/go"
        "/opt/go/bin/go"
    )

    # 1. 首先检查 PATH 中的 go
    if command -v go &>/dev/null; then
        go_path="$(command -v go)"
        echo "PATH 中的 Go: $go_path"
        echo "$go_path"
        return 0
    fi

    # 2. 检查常见安装位置
    for path in "${go_paths[@]}"; do
        if [ -x "$path" ]; then
            echo "找到 Go: $path"
            echo "$path"
            return 0
        fi
    done

    # 3. 使用 which 查找（sudo 环境）
    if command -v which &>/dev/null; then
        go_path="$(which go 2>/dev/null || true)"
        if [ -n "$go_path" ] && [ -x "$go_path" ]; then
            echo "which 找到 Go: $go_path"
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
    local go_bin_dir=""

    # 获取 Go 二进制文件路径
    GO_BINARY="$(find_go_binary)" || {
        echo ""
        echo "错误: 找不到 Go 可执行文件！"
        echo ""
        echo "请先安装 Go 或将 Go 添加到 PATH 中。"
        echo ""
        echo "安装 Go 1.22:"
        echo "  wget https://go.dev/dl/go1.22.0.linux-amd64.tar.gz"
        echo "  sudo tar -C /usr/local -xzf go1.22.0.linux-amd64.tar.gz"
        echo "  echo 'export PATH=\$PATH:/usr/local/go/bin' >> ~/.bashrc"
        echo "  source ~/.bashrc"
        exit 1
    }

    # 获取 Go 目录
    GO_DIR="$(dirname "$(dirname "$GO_BINARY")")"
    export GOROOT="${GO_DIR}"
    export PATH="${GO_DIR}/bin:${PATH}"

    echo ""
    echo "Go 环境配置:"
    echo "  GO_BINARY: $GO_BINARY"
    echo "  GOROOT: $GOROOT"
    echo "  PATH (前): $(echo $PATH | cut -d: -f1-3)"
}

# ============================================
# 函数: 检查 Go 版本
# ============================================
check_go_version() {
    local min_version="1.22"
    local current_version

    echo ""
    echo "检查 Go 版本..."

    current_version=$("$GO_BINARY" version 2>&1 | grep -oP 'go\d+\.\d+' | grep -oP '\d+\.\d+' || echo "0")

    if [ "$(echo "$current_version < $min_version" | bc 2>/dev/null || echo "1")" = "1" ]; then
        echo "警告: 当前 Go 版本 $current_version 低于要求的 $min_version"
        echo "某些依赖可能不兼容"
    fi

    "$GO_BINARY" version
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
    echo "已检查路径:"
    for path in "${possible_paths[@]}"; do
        echo "  - $path"
    done
    exit 1
}

# ============================================
# 主程序
# ============================================

# 1. 配置 Go 环境
setup_go_env

# 2. 检查 Go 版本
check_go_version

# 3. 备份原始 go.mod 和 go.sum
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

# 4. 移除不兼容的依赖版本
echo ""
echo "移除不兼容的依赖版本..."

# 移除 google.golang.org/genproto 相关的 require 行
sed -i '/google.golang.org\/genproto\/googleapis\/api/d' go.mod
sed -i '/google.golang.org\/genproto\/googleapis\/rpc/d' go.mod

# 移除 buf.build 相关依赖
sed -i '/buf.build\/gen\/go\/bufbuild/d' go.mod
sed -i '/buf.build\/go\/protovalidate/d' go.mod

echo "  已移除不兼容依赖"

# 5. 添加兼容 Go 1.22 的 replace 规则
echo ""
echo "添加兼容 Go 1.22 的依赖版本..."

# 检查是否已存在 replace 块
if grep -q "^replace" go.mod; then
    echo "  replace 块已存在，跳过添加"
else
    cat >> go.mod << 'EOF'

replace (
	google.golang.org/genproto/googleapis/api => google.golang.org/genproto/googleapis/api v0.0.0-20240814211410-ddb44dafa142
	google.golang.org/genproto/googleapis/rpc => google.golang.org/genproto/googleapis/rpc v0.0.0-20240814211410-ddb44dafa142
	google.golang.org/protobuf => google.golang.org/protobuf v1.33.0
)
EOF
    echo "  已添加 replace 块"
fi

# 6. 清理并重新下载依赖
echo ""
echo "清理并重新下载依赖..."
"$GO_BINARY" clean -modcache 2>/dev/null || true
"$GO_BINARY" mod tidy

# 7. 验证依赖
echo ""
echo "验证依赖..."
"$GO_BINARY" mod verify

echo ""
echo "========================================"
echo "  依赖修复完成！"
echo "========================================"
echo ""
echo "如果仍有问题，可以回滚："
echo "  cd $BACKEND_DIR"
echo "  mv go.mod.backup go.mod"
echo "  mv go.sum.backup go.sum"
