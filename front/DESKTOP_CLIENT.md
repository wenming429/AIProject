# LumenIM 桌面客户端构建指南

本文档说明如何使用 Electron 将 LumenIM Web 应用封装为原生桌面客户端。

## 目录结构

```
front/
├── electron/                 # Electron 主进程代码
│   ├── main.cjs             # 主进程入口
│   └── preload.cjs          # 预加载脚本
├── build/                   # 构建资源
│   └── icons/               # 应用图标
│       ├── lumenim.png      # 256x256 PNG 图标
│       ├── lumenim.ico      # Windows 图标
│       └── lumenim.icns     # macOS 图标
├── electron-builder.json    # electron-builder 配置
└── package.json            # 包含 Electron 脚本
```

## 快速开始

### 1. 安装依赖

```bash
cd front
npm install
```

### 2. 开发模式运行

```bash
# 同时启动前端和 Electron
npm run electron:dev
```

### 3. 构建应用

```bash
# 构建 Windows 版本
npm run electron:build:win

# 构建 macOS 版本
npm run electron:build:mac

# 构建 Linux 版本
npm run electron:build:linux

# 构建所有平台
npm run electron:build:all
```

构建完成后，安装包位于 `front/release/` 目录。

## 环境配置

### 前端 API 配置

编辑 `.env.electron` 文件，配置后端 API 地址：

```env
VITE_BASE_API=http://127.0.0.1:9501
VITE_SOCKET_API=ws://127.0.0.1:9502
```

### 生产环境配置

对于正式部署，需要配置实际的后端服务器地址：

```env
VITE_BASE_API=https://your-api-domain.com
VITE_SOCKET_API=wss://your-api-domain.com
```

## 功能特性

### 已实现功能

| 功能 | 说明 |
|------|------|
| 窗口管理 | 最小化、最大化、关闭、全屏 |
| 系统托盘 | 托盘图标、托盘菜单、托盘通知 |
| 消息通知 | 原生系统通知、任务栏徽章 |
| 本地存储 | 窗口状态持久化、配置存储 |
| 快捷键 | 标准桌面应用快捷键 |
| 自动更新 | 支持通过菜单检查更新（需配置更新服务器） |

### 快捷键

| 快捷键 | 功能 |
|--------|------|
| Cmd/Ctrl + W | 关闭当前窗口 |
| Cmd/Ctrl + M | 最小化 |
| Cmd/Ctrl + Q | 退出应用 |
| F11 | 全屏切换 |
| Cmd/Ctrl + R | 刷新页面 |
| Cmd/Ctrl + + | 放大 |
| Cmd/Ctrl + - | 缩小 |
| Cmd/Ctrl + 0 | 实际大小 |

## 自定义配置

### 修改窗口默认大小

编辑 `electron/main.cjs`：

```javascript
mainWindow = new BrowserWindow({
  width: 1200,    // 默认宽度
  height: 800,    // 默认高度
  minWidth: 900,  // 最小宽度
  minHeight: 600  // 最小高度
})
```

### 修改托盘菜单

编辑 `electron/main.cjs` 中的 `createTray` 函数：

```javascript
const contextMenu = Menu.buildFromTemplate([
  { label: '显示主窗口', click: () => mainWindow.show() },
  { type: 'separator' },
  { label: '退出', click: () => app.quit() }
])
```

### 添加开机启动

在 `electron/main.cjs` 的 `app.whenReady()` 中添加：

```javascript
app.setLoginItemSettings({
  openAtLogin: true,
  path: app.getPath('exe')
})
```

## 图标制作指南

应用图标应准备以下格式：

| 平台 | 文件名 | 尺寸要求 |
|------|--------|----------|
| 通用 | icon.png | 256x256 PNG |
| Windows | icon.ico | 多尺寸 16/32/48/256 |
| macOS | icon.icns | 16/32/64/128/256/512/1024 |

### Windows 图标制作

可以使用在线工具将 PNG 转换为 ICO：
- https://www.icoconverter.com/
- https://convertio.co/png-ico/

### macOS 图标制作

1. 准备 1024x1024 的 PNG 图片
2. 使用 macOS 自带工具 `iconutil` 或在线工具转换

## 常见问题

### Q: 构建失败，提示缺少模块

```bash
# 清理并重新安装
rm -rf node_modules package-lock.json
npm install
```

### Q: macOS 提示"无法打开，因为来自未识别的开发者"

在终端执行：
```bash
xattr -cr /path/to/LumenIM.app
```

### Q: Windows 杀毒软件误报

Electron 应用可能被某些杀毒软件误报。将应用添加到白名单或签名应用。

### Q: 图标显示不正确

确保图标文件格式正确，Windows 必须使用 ICO 格式。

## 生产部署

### 后端服务配置

确保后端服务正确配置 CORS，允许桌面客户端域名访问。

### SSL 证书

生产环境建议使用 HTTPS/WSS，配置方法见 `DEPLOYMENT_PRODUCTION.md`。

### 自动更新

配置 GitHub Releases 作为更新源，electron-builder 会自动处理版本检查和更新。

## 技术栈

- **Electron**: ^33.4.0
- **electron-builder**: ^25.1.8
- **Node.js**: >=18.0.0
