# LumenIM 桌面应用多环境配置清单

## 一、环境概述

| 环境 | 用途 | API 地址 | WebSocket 地址 | 应用标识 |
|------|------|----------|----------------|----------|
| **本地开发** | 本地调试 | `http://localhost:9501` | `ws://localhost:9502` | `com.lumenim.desktop.local` |
| **测试版** | 联调测试 | `http://192.168.23.131:9501` | `ws://192.168.23.131:9502` | `com.lumenim.desktop.test` |
| **正式版** | 生产环境 | `http://api.lumenim.com:9501` | `ws://api.lumenim.com:9502` | `com.lumenim.desktop` |

---

## 二、配置文件清单

### 2.1 前端环境配置 (.env 文件)

#### 本地开发 (.env.development)
```env
# 应用标识
VITE_APP_ENV=development
VITE_APP_TITLE="LumenIM (本地开发)"
VITE_BASE=/

# API 配置
VITE_BASE_API=http://localhost:9501
VITE_SOCKET_API=ws://localhost:9502

# 功能开关
VITE_ENABLE_DEBUG=true
VITE_ENABLE_MOCK=false
VITE_ENABLE_ANALYTICS=false

# 日志级别
VITE_LOG_LEVEL=debug
```

#### 测试版 (.env.test)
```env
# 应用标识
VITE_APP_ENV=test
VITE_APP_TITLE="LumenIM (测试版)"
VITE_BASE=/

# API 配置
VITE_BASE_API=http://192.168.23.131:9501
VITE_SOCKET_API=ws://192.168.23.131:9502

# 功能开关
VITE_ENABLE_DEBUG=true
VITE_ENABLE_MOCK=false
VITE_ENABLE_ANALYTICS=false

# 日志级别
VITE_LOG_LEVEL=debug
```

#### 正式版 (.env.production)
```env
# 应用标识
VITE_APP_ENV=production
VITE_APP_TITLE="LumenIM"
VITE_BASE=/

# API 配置
VITE_BASE_API=https://api.lumenim.com
VITE_SOCKET_API=wss://api.lumenim.com

# 功能开关
VITE_ENABLE_DEBUG=false
VITE_ENABLE_MOCK=false
VITE_ENABLE_ANALYTICS=true

# 日志级别
VITE_LOG_LEVEL=error
```

---

### 2.2 Tauri 应用配置 (src-tauri/tauri.conf.json)

| 配置项 | 本地开发 | 测试版 | 正式版 |
|--------|----------|--------|--------|
| **productName** | `LumenIM-Local` | `LumenIM-Test` | `LumenIM` |
| **version** | `1.0.0-dev` | `1.0.0-test` | `1.0.0` |
| **identifier** | `com.lumenim.desktop.local` | `com.lumenim.desktop.test` | `com.lumenim.desktop` |
| **app.windows[0].title** | `LumenIM (本地开发)` | `LumenIM (测试版)` | `LumenIM` |

#### 配置示例

**本地开发 (tauri.conf.dev.json)**
```json
{
  "productName": "LumenIM-Local",
  "version": "1.0.0-dev",
  "identifier": "com.lumenim.desktop.local",
  "app": {
    "windows": [
      {
        "title": "LumenIM (本地开发)",
        "width": 1200,
        "height": 800
      }
    ],
    "security": {
      "csp": "default-src 'self' http://localhost:* https://*; connect-src 'self' ipc: http://localhost:* https://* ws://localhost:* wss://localhost:* ws://* wss://*"
    }
  },
  "bundle": {
    "targets": ["nsis"],
    "windows": {
      "nsis": {
        "installMode": "currentUser"
      }
    }
  }
}
```

**测试版 (tauri.conf.test.json)**
```json
{
  "productName": "LumenIM-Test",
  "version": "1.0.0",
  "identifier": "com.lumenim.desktop.test",
  "app": {
    "windows": [
      {
        "title": "LumenIM (测试版)",
        "width": 1200,
        "height": 800
      }
    ],
    "security": {
      "csp": "default-src 'self' http://localhost:* http://192.168.23.131:* https://*; connect-src 'self' ipc: http://localhost:* http://192.168.23.131:* https://* ws://localhost:* wss://localhost:* ws://* wss://* ws://192.168.23.131:* wss://192.168.23.131:*"
    }
  },
  "bundle": {
    "targets": ["nsis"],
    "windows": {
      "nsis": {
        "installMode": "currentUser"
      }
    }
  }
}
```

**正式版 (tauri.conf.prod.json)**
```json
{
  "productName": "LumenIM",
  "version": "1.0.0",
  "identifier": "com.lumenim.desktop",
  "app": {
    "windows": [
      {
        "title": "LumenIM",
        "width": 1200,
        "height": 800
      }
    ],
    "security": {
      "csp": "default-src 'self' https://api.lumenim.com https://*; connect-src 'self' ipc: https://api.lumenim.com https://* ws://localhost:* wss://localhost:* ws://* wss://* wss://api.lumenim.com:*"
    }
  },
  "bundle": {
    "targets": ["nsis", "msi"],
    "windows": {
      "nsis": {
        "installMode": "perMachine"
      }
    }
  }
}
```

---

### 2.3 Cargo 配置 (src-tauri/Cargo.toml)

| 配置项 | 本地开发 | 测试版 | 正式版 |
|--------|----------|--------|--------|
| **package.name** | `lumenim-desktop-local` | `lumenim-desktop-test` | `lumenim-desktop` |
| **package.version** | `1.0.0-dev` | `1.0.0-test` | `1.0.0` |
| **package.description** | `LumenIM Desktop (Local Dev)` | `LumenIM Desktop (Test)` | `LumenIM Desktop` |

---

## 三、CSP 安全策略配置

### 3.1 CSP 配置说明

CSP (Content Security Policy) 控制应用可以连接的网络资源。

### 3.2 各环境 CSP 配置

#### 本地开发
```
default-src 'self' http://localhost:* https://*; 
script-src 'self' 'unsafe-inline' 'unsafe-eval'; 
style-src 'self' 'unsafe-inline'; 
img-src 'self' data: blob: asset: https: http://localhost:*; 
connect-src 'self' ipc: http://localhost:* https://* ws://localhost:* wss://localhost:* ws://* wss://*; 
media-src 'self' blob: http://localhost:* https://*
```

#### 测试版
```
default-src 'self' http://localhost:* http://192.168.23.131:* https://*; 
script-src 'self' 'unsafe-inline' 'unsafe-eval'; 
style-src 'self' 'unsafe-inline'; 
img-src 'self' data: blob: asset: https: http://localhost:* http://192.168.23.131:*; 
connect-src 'self' ipc: http://localhost:* http://192.168.23.131:* https://* ws://localhost:* wss://localhost:* ws://* wss://* ws://192.168.23.131:* wss://192.168.23.131:*; 
media-src 'self' blob: http://localhost:* http://192.168.23.131:* https://*
```

#### 正式版
```
default-src 'self' https://api.lumenim.com https://*; 
script-src 'self' 'unsafe-inline' 'unsafe-eval'; 
style-src 'self' 'unsafe-inline'; 
img-src 'self' data: blob: asset: https://api.lumenim.com https://*; 
connect-src 'self' ipc: https://api.lumenim.com https://* ws://localhost:* wss://localhost:* ws://* wss://* wss://api.lumenim.com:*; 
media-src 'self' blob: https://api.lumenim.com https://*
```

---

## 四、构建输出配置

### 4.1 输出目录结构

```
src-tauri/target/
├── release_local/          # 本地开发版
│   ├── lumenim-desktop.exe
│   └── bundle/
│       └── nsis/LumenIM-Local_x64-setup.exe
├── release_test/           # 测试版
│   ├── lumenim-desktop.exe
│   └── bundle/
│       └── nsis/LumenIM-Test_x64-setup.exe
└── release/               # 正式版
    ├── lumenim-desktop.exe
    └── bundle/
        ├── nsis/LumenIM_x.x.x_x64-setup.exe
        └── msi/LumenIM_x.x.x_x64_en-US.msi
```

### 4.2 安装包命名规则

| 环境 | 安装包命名格式 | 示例 |
|------|----------------|------|
| 本地开发 | `{ProductName}_Local_{Version}_x64-setup.exe` | `LumenIM_Local_1.0.0-dev_x64-setup.exe` |
| 测试版 | `{ProductName}_Test_{Version}_x64-setup.exe` | `LumenIM_Test_1.0.0_x64-setup.exe` |
| 正式版 | `{ProductName}_{Version}_x64-setup.exe` | `LumenIM_1.0.0_x64-setup.exe` |

---

## 五、环境切换方式

### 5.1 方式一：命令行参数

```bash
# 本地开发版
npm run build -- --mode development
npx tauri build

# 测试版
npm run build -- --mode test
npx tauri build

# 正式版
npm run build -- --mode production
npx tauri build
```

### 5.2 方式二：环境变量

```bash
# 本地开发版
TAURI_ENV=local npx tauri build

# 测试版
TAURI_ENV=test npx tauri build

# 正式版
TAURI_ENV=prod npx tauri build
```

### 5.3 方式三：专用构建脚本

```bash
# Windows
scripts/build-local.bat
scripts/build-test.bat
scripts/build-prod.bat

# 或一键构建所有环境
scripts/build-all.bat
```

---

## 六、完整构建脚本

### 6.1 本地开发版构建脚本 (build-local.bat)

```batch
@echo off
echo ========================================
echo   LumenIM 桌面应用 - 本地开发版构建
echo ========================================

REM 切换到项目目录
cd /d "%~dp0..\front"

REM 清理旧构建
if exist "src-tauri\target\release_local" rmdir /s /q "src-tauri\target\release_local"

REM 构建前端
echo [1/3] 构建前端...
call npm run build -- --mode development

REM 复制 Tauri 配置
echo [2/3] 复制配置文件...
copy /y "src-tauri\tauri.conf.local.json" "src-tauri\tauri.conf.json" >nul
copy /y "src-tauri\Cargo.local.toml" "src-tauri\Cargo.toml" >nul

REM 构建 Tauri
echo [3/3] 构建 Tauri 应用...
npx tauri build

REM 移动到输出目录
if not exist "src-tauri\target\release_local" mkdir "src-tauri\target\release_local"
copy /y "src-tauri\target\release\lumenim-desktop.exe" "src-tauri\target\release_local\" >nul
xcopy /y /e "src-tauri\target\release\bundle" "src-tauri\target\release_local\bundle\" >nul

echo ========================================
echo   构建完成！
echo   输出目录: src-tauri\target\release_local
echo ========================================
pause
```

### 6.2 测试版构建脚本 (build-test.bat)

```batch
@echo off
echo ========================================
echo   LumenIM 桌面应用 - 测试版构建
echo ========================================

cd /d "%~dp0..\front"

REM 清理
if exist "src-tauri\target\release_test" rmdir /s /q "src-tauri\target\release_test"

REM 构建前端
echo [1/3] 构建前端...
call npm run build -- --mode test

REM 复制配置
echo [2/3] 复制配置文件...
copy /y "src-tauri\tauri.conf.test.json" "src-tauri\tauri.conf.json" >nul
copy /y "src-tauri\Cargo.test.toml" "src-tauri\Cargo.toml" >nul

REM 构建 Tauri
echo [3/3] 构建 Tauri 应用...
npx tauri build

REM 移动到输出目录
if not exist "src-tauri\target\release_test" mkdir "src-tauri\target\release_test"
copy /y "src-tauri\target\release\lumenim-desktop.exe" "src-tauri\target\release_test\" >nul
xcopy /y /e "src-tauri\target\release\bundle" "src-tauri\target\release_test\bundle\" >nul

echo ========================================
echo   构建完成！
echo   输出目录: src-tauri\target\release_test
echo ========================================
pause
```

### 6.3 正式版构建脚本 (build-prod.bat)

```batch
@echo off
echo ========================================
echo   LumenIM 桌面应用 - 正式版构建
echo ========================================

cd /d "%~dp0..\front"

REM 清理
if exist "src-tauri\target\release" rmdir /s /q "src-tauri\target\release"

REM 构建前端
echo [1/3] 构建前端...
call npm run build -- --mode production

REM 复制配置
echo [2/3] 复制配置文件...
copy /y "src-tauri\tauri.conf.prod.json" "src-tauri\tauri.conf.json" >nul
copy /y "src-tauri\Cargo.toml" "src-tauri\Cargo.toml" >nul

REM 构建 Tauri
echo [3/3] 构建 Tauri 应用...
npx tauri build

echo ========================================
echo   构建完成！
echo   输出目录: src-tauri\target\release
echo ========================================
pause
```

### 6.4 一键构建所有环境 (build-all.bat)

```batch
@echo off
echo ========================================
echo   LumenIM 桌面应用 - 全环境构建
echo ========================================

echo [1/3] 构建本地开发版...
call "%~dp0build-local.bat"

echo [2/3] 构建测试版...
call "%~dp0build-test.bat"

echo [3/3] 构建正式版...
call "%~dp0build-prod.bat"

echo ========================================
echo   所有环境构建完成！
echo   本地版: src-tauri\target\release_local
echo   测试版: src-tauri\target\release_test
echo   正式版: src-tauri\target\release
echo ========================================
pause
```

---

## 七、配置对比速查表

| 配置分类 | 配置项 | 本地开发 | 测试版 | 正式版 |
|----------|--------|----------|--------|--------|
| **应用信息** | 产品名称 | LumenIM-Local | LumenIM-Test | LumenIM |
| | 版本号 | 1.0.0-dev | 1.0.0 | 1.0.0 |
| | 应用ID | com.lumenim.desktop.local | com.lumenim.desktop.test | com.lumenim.desktop |
| | 窗口标题 | LumenIM (本地开发) | LumenIM (测试版) | LumenIM |
| **API配置** | API 地址 | http://localhost:9501 | http://192.168.23.131:9501 | https://api.lumenim.com |
| | WebSocket | ws://localhost:9502 | ws://192.168.23.131:9502 | wss://api.lumenim.com |
| **安全策略** | CSP 允许 HTTP | localhost | localhost, 192.168.23.131 | api.lumenim.com |
| | CSP 允许 WS | ws://localhost | ws://192.168.23.131 | wss://api.lumenim.com |
| **功能开关** | 调试模式 | true | true | false |
| | 分析功能 | false | false | true |
| **日志配置** | 日志级别 | debug | debug | error |
| **构建配置** | 安装模式 | currentUser | currentUser | perMachine |
| | 包含 MSI | 否 | 否 | 是 |
| **输出目录** | 构建输出 | release_local | release_test | release |

---

## 八、环境隔离策略

### 8.1 配置文件隔离

```
front/src-tauri/
├── tauri.conf.json              # 默认配置（不提交）
├── tauri.conf.dev.json          # 本地开发配置
├── tauri.conf.test.json          # 测试版配置
├── tauri.conf.prod.json         # 正式版配置
├── Cargo.toml                   # 默认配置
├── Cargo.dev.toml               # 本地开发 Rust 配置
├── Cargo.test.toml              # 测试版 Rust 配置
└── .env.local                   # 本地环境变量（不提交）
```

### 8.2 .gitignore 配置

```
# 环境敏感文件
.env.local
.env.*.local
tauri.conf.json
Cargo.toml

# 构建产物
src-tauri/target/
release_local/
release_test/
```

---

## 九、版本号管理

### 9.1 版本号规则

| 版本类型 | 格式 | 示例 | 说明 |
|----------|------|------|------|
| 开发版 | {major}.{minor}.{patch}-dev | 1.0.0-dev | 开发中 |
| 测试版 | {major}.{minor}.{patch} | 1.0.0 | 已发布测试 |
| 正式版 | {major}.{minor}.{patch} | 1.0.0 | 已发布生产 |
| 预发布 | {major}.{minor}.{patch}-rc1 | 1.1.0-rc1 | 候选版本 |

### 9.2 版本升级规则

- **主版本 (major)**: 重大架构变更，不兼容更新
- **次版本 (minor)**: 新功能向后兼容
- **修订版 (patch)**: Bug 修复
- **预发布 (-dev/-rc)**: 开发/预发布标识

---

## 十、快速参考

### 常用构建命令

```bash
# 本地开发
npm run dev

# 打包本地开发版
npm run build -- --mode development
npx tauri build

# 打包测试版
npm run build -- --mode test
npx tauri build

# 打包正式版
npm run build -- --mode production
npx tauri build
```

### 配置文件位置

| 配置文件 | 路径 |
|----------|------|
| 前端环境变量 | `front/.env.{mode}` |
| Tauri 配置 | `front/src-tauri/tauri.conf.{env}.json` |
| Rust 配置 | `front/src-tauri/Cargo.{env}.toml` |
| 构建脚本 | `scripts/*.bat` |
