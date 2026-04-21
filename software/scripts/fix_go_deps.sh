#!/bin/bash
#
# Go 依赖修复脚本
# 用于解决 Go 1.22 环境下的依赖版本兼容问题
#
# 使用方法: ./fix_go_deps.sh
#

set -e

echo "========================================"
echo "  Go 依赖修复脚本"
echo "========================================"

# 设置 Go 代理
export GOPROXY=https://goproxy.cn,direct
export GOSUMDB=off
export GOTOOLCHAIN=local

# 进入后端目录
cd "$(dirname "$0")/.."
cd backend

echo ""
echo "1. 备份原始 go.mod 和 go.sum"
cp go.mod go.mod.backup
cp go.sum go.sum.backup

echo ""
echo "2. 检查当前 Go 版本"
go version

echo ""
echo "3. 移除不兼容的依赖版本..."
# 移除 google.golang.org/genproto 相关的依赖（需要 Go 1.24+）
sed -i '/google.golang.org\/genproto\/googleapis\/api/d' go.mod
sed -i '/google.golang.org\/genproto\/googleapis\/rpc/d' go.mod

# 移除 buf.build 相关依赖（可能不兼容）
sed -i '/buf.build\/gen\/go\/bufbuild/d' go.mod
sed -i '/buf.build\/go\/protovalidate/d' go.mod

echo ""
echo "4. 添加兼容 Go 1.22 的依赖版本..."

# 添加兼容版本的依赖
cat >> go.mod << 'EOF'

replace (
	google.golang.org/genproto/googleapis/api => google.golang.org/genproto/googleapis/api v0.0.0-20240814211410-ddb44dafa142
	google.golang.org/genproto/googleapis/rpc => google.golang.org/genproto/googleapis/rpc v0.0.0-20240814211410-ddb44dafa142
	google.golang.org/protobuf => google.golang.org/protobuf v1.33.0
)
EOF

echo ""
echo "5. 清理并重新下载依赖..."
go clean -modcache 2>/dev/null || true
go mod tidy

echo ""
echo "6. 验证依赖..."
go mod verify

echo ""
echo "========================================"
echo "  依赖修复完成！"
echo "========================================"
echo ""
echo "如果仍有问题，可以回滚："
echo "  mv go.mod.backup go.mod"
echo "  mv go.sum.backup go.sum"
