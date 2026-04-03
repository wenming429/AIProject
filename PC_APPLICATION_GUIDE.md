# LumenIM PC版应用程序指南

完整的企业级即时通讯桌面客户端构建与部署文档。

## 📋 目录

1. [功能特性](#功能特性)
2. [系统要求](#系统要求)
3. [快速开始](#快速开始)
4. [构建指南](#构建指南)
5. [安装部署](#安装部署)
6. [配置说明](#配置说明)
7. [常见问题](#常见问题)

## ✨ 功能特性

### 核心功能
| 功能模块 | 描述 |
|---------|------|
| 💬 即时通讯 | 支持文字、图片、文件、语音消息 |
| 👥 群组管理 | 创建群聊、邀请成员、群设置 |
| 🏢 组织架构 | 企业部门树、人员管理 |
| 📝 笔记系统 | 个人笔记、分类管理 |
| 🔔 消息通知 | 系统托盘通知、任务栏徽章 |
| 🎨 主题皮肤 | 华夏红/浅灰主题切换 |

### 桌面端特性
| 特性 | 说明 |
|------|------|
| 📌 系统托盘 | 最小化到托盘、托盘菜单 |
| 🚀 开机自启 | 支持开机自动启动 |
| 💾 本地存储 | 配置持久化、缓存管理 |
| ⌨️ 全局快捷键 | Ctrl+N新建、Ctrl+W关闭等 |
| 🖥️ 多显示器 | 支持多显示器环境 |
| 🔒 安全隔离 | 上下文隔离、安全策略 |

## 💻 系统要求

### 开发环境
- **Node.js**: >= 18.0.0
- **pnpm**: >= 8.0.0
- **Git**: 任意版本
- **操作系统**: Windows 10/11, macOS 12+, Ubuntu 20.04+

### 运行环境
- **Windows**: Windows 10 版本 1809 或更高
- **macOS**: macOS 12 (Monterey) 或更高
- **Linux**: Ubuntu 20.04+, Debian 11+, Fedora 35+

## 🚀 快速开始

### 方式一：使用构建脚本（推荐）

```bash
# Windows
双击运行 build-pc-app.bat

# 选择构建选项：
# [1] 开发模式 - 热重载调试
# [2] Windows安装包 - 生成安装程序
# [3] Windows便携版 - 免安装版本
# [4] 所有版本 - 同时构建多种格式
```

### 方式二：手动构建

```bash
# 1. 进入前端目录
cd front

# 2. 安装依赖
pnpm install

# 3. 开发模式运行
pnpm run electron:dev

# 4. 构建生产版本
pnpm run electron:build:win
```

## 🔨 构建指南

### 构建配置

编辑 `front/electron-builder.json`：

```json
{
  "appId": "com.lumenim.app",
  "productName": "LumenIM",
  "copyright": "Copyright © 2024 LumenIM",
  
  "win": {
    "target": [
      {
        "target": "nsis",      // Windows安装程序
        "arch": ["x64"]
      },
      {
        "target": "portable",  // 便携版
        "arch": ["x64"]
      }
    ],
    "icon": "build/icons/icon.ico"
  },
  
  "nsis": {
    "oneClick": false,                    // 非一键安装
    "perMachine": false,                  // 按用户安装
    "allowToChangeInstallationDirectory": true,  // 允许选择安装路径
    "createDesktopShortcut": true,        // 创建桌面快捷方式
    "createStartMenuShortcut": true       // 创建开始菜单快捷方式
  }
}
```

### 构建命令

```bash
# 开发模式
pnpm run electron:dev

# 构建Windows安装包
pnpm run electron:build:win

# 构建macOS版本
pnpm run electron:build:mac

# 构建Linux版本
pnpm run electron:build:linux

# 构建所有平台
pnpm run electron:build:all
```

### 输出文件

构建完成后，安装包位于 `front/release/` 目录：

```
release/
├── LumenIM-1.0.0-x64.exe          # Windows安装程序
├── LumenIM-1.0.0-x64-portable.exe # Windows便携版
├── LumenIM-1.0.0-x64.dmg          # macOS安装包
├── LumenIM-1.0.0-x64.AppImage     # Linux AppImage
└── latest.yml                     # 自动更新配置
```

## 📦 安装部署

### Windows安装

1. **运行安装程序**
   - 双击 `LumenIM-1.0.0-x64.exe`
   - 按向导提示完成安装

2. **安装选项**
   - 选择安装路径（默认：`%LOCALAPPDATA%\Programs\LumenIM`）
   - 创建桌面快捷方式（可选）
   - 创建开始菜单快捷方式（可选）

3. **首次启动**
   - 自动创建用户数据目录
   - 生成默认配置文件
   - 显示登录界面

### 便携版使用

1. **下载便携版**
   - 下载 `LumenIM-1.0.0-x64-portable.exe`

2. **放置到任意位置**
   - U盘、移动硬盘或本地目录

3. **直接运行**
   - 双击即可启动
   - 配置保存在程序目录

### 企业部署

#### MSI静默安装

```powershell
# 静默安装
LumenIM-1.0.0-x64.exe /S

# 指定安装目录
LumenIM-1.0.0-x64.exe /S /D=C:\LumenIM
```

#### 组策略部署

1. 将安装包复制到网络共享
2. 创建GPO进行软件分发
3. 客户端自动安装

## ⚙️ 配置说明

### 配置文件位置

```
Windows: %APPDATA%\LumenIM\config.json
macOS:   ~/Library/Application Support/LumenIM/config.json
Linux:   ~/.config/LumenIM/config.json
```

### 配置项说明

```json
{
  "windowWidth": 1200,        // 窗口宽度
  "windowHeight": 800,        // 窗口高度
  "windowX": 100,             // 窗口X位置
  "windowY": 100,             // 窗口Y位置
  "isMaximized": false,       // 是否最大化
  "isFullScreen": false,      // 是否全屏
  "theme": "light",           // 主题: light/dark
  "language": "zh-CN",        // 语言
  "notification": {
    "enabled": true,          // 通知开关
    "sound": true,            // 声音提示
    "badge": true             // 徽章显示
  },
  "autoStart": false,         // 开机自启
  "minimizeToTray": true,     // 最小化到托盘
  "closeToTray": true,        // 关闭到托盘
  "downloadPath": "..."       // 下载路径
}
```

### 环境变量配置

创建 `front/.env.electron`：

```env
# API配置
VITE_BASE_API=http://127.0.0.1:9501
VITE_SOCKET_API=ws://127.0.0.1:9502

# 功能开关
VITE_ENABLE_NOTIFICATION=true
VITE_ENABLE_AUTO_UPDATE=true
```

## ❓ 常见问题

### Q: 构建失败，提示缺少Python

**A**: Windows需要安装Python和Visual Studio构建工具

```powershell
# 安装windows-build-tools
npm install --global windows-build-tools

# 或手动安装
# 1. 安装 Python 3.x
# 2. 安装 Visual Studio Build Tools
```

### Q: macOS提示"无法打开，因为来自未识别的开发者"

**A**: 执行以下命令移除隔离属性

```bash
xattr -cr /Applications/LumenIM.app
```

### Q: Windows杀毒软件误报

**A**: 
1. 将应用添加到杀毒软件白名单
2. 或购买代码签名证书进行签名

### Q: 如何修改默认API地址

**A**: 编辑 `front/.env.electron` 文件

```env
VITE_BASE_API=https://your-api-server.com
VITE_SOCKET_API=wss://your-api-server.com
```

### Q: 如何启用自动更新

**A**: 
1. 配置GitHub Releases作为更新源
2. 编辑 `electron-builder.json`:

```json
{
  "publish": {
    "provider": "github",
    "owner": "your-github-username",
    "repo": "LumenIM"
  }
}
```

### Q: 应用启动白屏

**A**: 
1. 检查后端API是否可访问
2. 查看日志文件：`%APPDATA%\LumenIM\logs\`
3. 清除缓存后重试

### Q: 通知不显示

**A**: 
1. Windows: 检查系统通知设置
2. macOS: 在系统偏好设置中允许通知
3. 检查应用内通知设置是否开启

## 📞 技术支持

- **GitHub Issues**: https://github.com/gzydong/LumenIM/issues
- **文档中心**: https://github.com/gzydong/LumenIM/tree/master/docs
- **更新日志**: https://github.com/gzydong/LumenIM/releases

## 📄 许可证

MIT License - 详见 [LICENSE](../LICENSE) 文件

---

**LumenIM** © 2024 LumenIM Team. All Rights Reserved.
