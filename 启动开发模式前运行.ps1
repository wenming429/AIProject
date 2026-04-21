cd front

# 清理 Vite 缓存
Remove-Item -Recurse -Force node_modules\.vite -ErrorAction SilentlyContinue

# 启动开发模式
pnpm run electron:dev
