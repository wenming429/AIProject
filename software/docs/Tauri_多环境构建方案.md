# Tauri 多环境桌面应用构建方案

## 一、方案概述

本方案提供一套完整的 Tauri + React/Vue 前端的桌面应用构建系统，支持：
- **本地开发版** (dev)
- **测试版** (test)
- **正式版** (prod)

通过配置文件和环境变量实现不同环境间的平滑切换。

---

## 二、项目结构

```
tauri-app/
├── src/                          # 前端源码
│   ├── main.tsx
│   ├── App.tsx
│   ├── config/                   # 配置文件
│   │   ├── index.ts              # 配置入口
│   │   ├── dev.ts                # 开发环境配置
│   │   ├── test.ts               # 测试环境配置
│   │   └── prod.ts               # 正式环境配置
│   ├── api/                      # API 请求
│   │   └── client.ts
│   └── services/                 # 业务服务
├── src-tauri/                    # Rust 后端
│   ├── src/
│   │   ├── main.rs
│   │   ├── config.rs             # 配置管理
│   │   ├── commands.rs           # Tauri 命令
│   │   └── lib.rs
│   ├── tauri.conf.json           # Tauri 配置
│   ├── Cargo.toml
│   └── .env                      # 环境变量
├── scripts/                      # 构建脚本
│   ├── build-dev.sh
│   ├── build-test.sh
│   ├── build-prod.sh
│   └── build-all.sh
├── package.json
├── vite.config.ts
└── tsconfig.json
```

---

## 三、前端配置方案

### 3.1 环境配置文件

#### `src/config/dev.ts` - 开发环境

```typescript
/**
 * 开发环境配置
 */
export const devConfig = {
  // 应用信息
  app: {
    name: 'Tauri App (Dev)',
    version: '1.0.0-dev',
    build: 'development',
  },

  // API 配置
  api: {
    baseUrl: 'http://localhost:8080/api',
    timeout: 30000,
    retry: 3,
  },

  // WebSocket 配置
  websocket: {
    url: 'ws://localhost:9502',
    reconnectInterval: 3000,
    maxReconnectAttempts: 10,
  },

  // 日志配置
  log: {
    level: 'debug',           // 日志级别: trace, debug, info, warn, error
    enableConsole: true,     // 控制台输出
    enableFile: false,       // 文件输出
    maxFileSize: 10 * 1024 * 1024,  // 10MB
  },

  // 功能开关
  features: {
    enableDebug: true,        // 调试模式
    enableHotReload: true,    // 热更新
    enableMockData: true,     // 使用模拟数据
    enableAnalytics: false,   // 数据分析
    enableCrashReport: false, // 崩溃报告
    enableUpdateCheck: false, // 自动更新检查
  },

  // UI 配置
  ui: {
    theme: 'light',           // 主题: light, dark, auto
    language: 'zh-CN',       // 语言
    showDevTools: true,      // 显示开发者工具
  },

  // 数据库配置
  database: {
    host: 'localhost',
    port: 3306,
    name: 'tauri_dev',
  },
};
```

#### `src/config/test.ts` - 测试环境

```typescript
/**
 * 测试环境配置
 */
export const testConfig = {
  app: {
    name: 'Tauri App (Test)',
    version: '1.0.0-beta',
    build: 'test',
  },

  api: {
    baseUrl: 'http://192.168.1.100:8080/api',
    timeout: 15000,
    retry: 2,
  },

  websocket: {
    url: 'ws://192.168.1.100:9502',
    reconnectInterval: 5000,
    maxReconnectAttempts: 5,
  },

  log: {
    level: 'info',
    enableConsole: true,
    enableFile: true,
    maxFileSize: 5 * 1024 * 1024,
  },

  features: {
    enableDebug: true,
    enableHotReload: false,
    enableMockData: false,
    enableAnalytics: true,
    enableCrashReport: true,
    enableUpdateCheck: true,
  },

  ui: {
    theme: 'auto',
    language: 'zh-CN',
    showDevTools: false,
  },

  database: {
    host: '192.168.1.100',
    port: 3306,
    name: 'tauri_test',
  },
};
```

#### `src/config/prod.ts` - 正式环境

```typescript
/**
 * 正式环境配置
 */
export const prodConfig = {
  app: {
    name: 'Tauri App',
    version: '1.0.0',
    build: 'production',
  },

  api: {
    baseUrl: 'https://api.example.com/api',
    timeout: 10000,
    retry: 1,
  },

  websocket: {
    url: 'wss://api.example.com/wss',
    reconnectInterval: 10000,
    maxReconnectAttempts: 3,
  },

  log: {
    level: 'error',           // 生产环境只记录错误
    enableConsole: false,
    enableFile: true,
    maxFileSize: 5 * 1024 * 1024,
  },

  features: {
    enableDebug: false,
    enableHotReload: false,
    enableMockData: false,
    enableAnalytics: true,
    enableCrashReport: true,
    enableUpdateCheck: true,
  },

  ui: {
    theme: 'auto',
    language: 'zh-CN',
    showDevTools: false,
  },

  database: {
    host: 'db.example.com',
    port: 3306,
    name: 'tauri_prod',
  },
};
```

### 3.2 配置入口文件

#### `src/config/index.ts`

```typescript
/**
 * Tauri 多环境配置入口
 * 根据环境变量自动加载对应配置
 */

import { devConfig } from './dev';
import { testConfig } from './test';
import { prodConfig } from './prod';

// 环境类型
export type EnvType = 'dev' | 'test' | 'prod';

// 配置类型
export interface AppConfig {
  app: {
    name: string;
    version: string;
    build: string;
  };
  api: {
    baseUrl: string;
    timeout: number;
    retry: number;
  };
  websocket: {
    url: string;
    reconnectInterval: number;
    maxReconnectAttempts: number;
  };
  log: {
    level: string;
    enableConsole: boolean;
    enableFile: boolean;
    maxFileSize: number;
  };
  features: Record<string, boolean>;
  ui: {
    theme: string;
    language: string;
    showDevTools: boolean;
  };
  database: {
    host: string;
    port: number;
    name: string;
  };
}

// 配置映射
const configMap: Record<EnvType, AppConfig> = {
  dev: devConfig,
  test: testConfig,
  prod: prodConfig,
};

// 获取当前环境
function getCurrentEnv(): EnvType {
  // 优先级: 1. window.__ENV__  2. import.meta.env  3. 默认开发环境
  if (typeof window !== 'undefined' && (window as any).__ENV__) {
    return (window as any).__ENV__;
  }

  if (import.meta.env?.MODE) {
    const mode = import.meta.env.MODE as string;
    if (mode === 'production') return 'prod';
    if (mode === 'test') return 'test';
  }

  return 'dev';
}

// 导出当前配置
const currentEnv = getCurrentEnv();
export const config: AppConfig = configMap[currentEnv];

// 导出环境信息
export const envInfo = {
  current: currentEnv,
  isDev: currentEnv === 'dev',
  isTest: currentEnv === 'test',
  isProd: currentEnv === 'prod',
};

// 导出获取配置的函数
export function getConfig(): AppConfig {
  return config;
}

export function getConfigByEnv(env: EnvType): AppConfig {
  return configMap[env];
}

// 打印配置信息（仅开发环境）
if (envInfo.isDev) {
  console.log('[Config] Current environment:', currentEnv);
  console.log('[Config] API Base URL:', config.api.baseUrl);
  console.log('[Config] Features:', config.features);
}

export default config;
```

### 3.3 Vite 环境变量配置

#### `.env.development`

```env
# 开发环境变量
VITE_APP_ENV=dev
VITE_APP_TITLE="Tauri App (Dev)"
VITE_API_BASE_URL=http://localhost:8080/api
VITE_WS_URL=ws://localhost:9502
VITE_ENABLE_MOCK=true
VITE_LOG_LEVEL=debug
```

#### `.env.test`

```env
# 测试环境变量
VITE_APP_ENV=test
VITE_APP_TITLE="Tauri App (Test)"
VITE_API_BASE_URL=http://192.168.1.100:8080/api
VITE_WS_URL=ws://192.168.1.100:9502
VITE_ENABLE_MOCK=false
VITE_LOG_LEVEL=info
```

#### `.env.production`

```env
# 生产环境变量
VITE_APP_ENV=prod
VITE_APP_TITLE="Tauri App"
VITE_API_BASE_URL=https://api.example.com/api
VITE_WS_URL=wss://api.example.com/wss
VITE_ENABLE_MOCK=false
VITE_LOG_LEVEL=error
```

---

## 四、Tauri 后端配置方案

### 4.1 Tauri 配置文件

#### `src-tauri/tauri.conf.json`

```json
{
  "$schema": "https://schema.tauri.app/config/2",
  "productName": "Tauri App",
  "version": "1.0.0",
  "identifier": "com.example.tauri-app",
  "build": {
    "frontendDist": "../dist",
    "devUrl": "http://localhost:5173",
    "beforeDevCommand": "npm run dev",
    "beforeBuildCommand": "npm run build",
    "devtools": true
  },
  "app": {
    "windows": [
      {
        "title": "Tauri App",
        "width": 1200,
        "height": 800,
        "minWidth": 800,
        "minHeight": 600,
        "resizable": true,
        "fullscreen": false,
        "center": true
      }
    ],
    "security": {
      "csp": null
    }
  },
  "bundle": {
    "active": true,
    "targets": "all",
    "icon": [
      "icons/32x32.png",
      "icons/128x128.png",
      "icons/128x128@2x.png",
      "icons/icon.icns",
      "icons/icon.ico"
    ],
    "windows": {
      "webviewInstallMode": {
        "type": "embedBootstrapper"
      }
    }
  }
}
```

### 4.2 Rust 配置管理

#### `src-tauri/src/config.rs`

```rust
use serde::{Deserialize, Serialize};
use std::env;
use std::fs;
use std::path::PathBuf;

/// 应用环境
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub enum AppEnv {
    Dev,
    Test,
    Prod,
}

impl Default for AppEnv {
    fn default() -> Self {
        AppEnv::Dev
    }
}

impl AppEnv {
    pub fn from_str(s: &str) -> Self {
        match s.to_lowercase().as_str() {
            "dev" | "development" => AppEnv::Dev,
            "test" | "staging" => AppEnv::Test,
            "prod" | "production" => AppEnv::Prod,
            _ => AppEnv::Dev,
        }
    }

    pub fn as_str(&self) -> &'static str {
        match self {
            AppEnv::Dev => "dev",
            AppEnv::Test => "test",
            AppEnv::Prod => "prod",
        }
    }
}

/// 应用配置
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AppConfig {
    pub env: AppEnv,

    // 应用信息
    pub app_name: String,
    pub app_version: String,

    // API 配置
    pub api_base_url: String,
    pub api_timeout: u64,

    // WebSocket 配置
    pub ws_url: String,
    pub ws_reconnect_interval: u64,

    // 日志配置
    pub log_level: String,
    pub log_dir: PathBuf,

    // 功能开关
    pub enable_debug: bool,
    pub enable_mock: bool,
    pub enable_crash_report: bool,

    // 数据库配置
    pub db_host: String,
    pub db_port: u16,
    pub db_name: String,
}

impl Default for AppConfig {
    fn default() -> Self {
        Self::from_env(AppEnv::Dev)
    }
}

impl AppConfig {
    /// 从环境变量加载配置
    pub fn from_env(env: AppEnv) -> Self {
        let env_str = env.as_str();

        // 从环境变量读取，使用环境名称作为前缀
        let prefix = format!("{}_", env_str.to_uppercase());

        // 获取环境变量，优先级: 显式设置 > .env 文件 > 默认值
        let get_env = |key: &str, default: &str| -> String {
            env::var(&format!("{prefix}{key}"))
                .or_else(|_| env::var(key))
                .unwrap_or_else(|_| default.to_string())
        };

        let get_env_bool = |key: &str, default: bool| -> bool {
            env::var(&format!("{prefix}{key}"))
                .or_else(|_| env::var(key))
                .map(|v| v == "true" || v == "1")
                .unwrap_or(default)
        };

        let get_env_u64 = |key: &str, default: u64| -> u64 {
            env::var(&format!("{prefix}{key}"))
                .or_else(|_| env::var(key))
                .ok()
                .and_then(|v| v.parse().ok())
                .unwrap_or(default)
        };

        let get_env_u16 = |key: &str, default: u16| -> u16 {
            env::var(&format!("{prefix}{key}"))
                .or_else(|_| env::var(key))
                .ok()
                .and_then(|v| v.parse().ok())
                .unwrap_or(default)
        };

        let log_dir = dirs::data_local_dir()
            .unwrap_or_else(|| PathBuf::from("."))
            .join("TauriApp")
            .join("logs");

        match env {
            AppEnv::Dev => AppConfig {
                env,
                app_name: get_env("APP_NAME", "Tauri App (Dev)"),
                app_version: get_env("APP_VERSION", "1.0.0-dev"),
                api_base_url: get_env("API_BASE_URL", "http://localhost:8080/api"),
                api_timeout: get_env_u64("API_TIMEOUT", 30000),
                ws_url: get_env("WS_URL", "ws://localhost:9502"),
                ws_reconnect_interval: get_env_u64("WS_RECONNECT_INTERVAL", 3000),
                log_level: get_env("LOG_LEVEL", "debug"),
                log_dir: log_dir.join("dev"),
                enable_debug: true,
                enable_mock: get_env_bool("ENABLE_MOCK", true),
                enable_crash_report: false,
                db_host: get_env("DB_HOST", "localhost"),
                db_port: get_env_u16("DB_PORT", 3306),
                db_name: get_env("DB_NAME", "tauri_dev"),
            },

            AppEnv::Test => AppConfig {
                env,
                app_name: get_env("APP_NAME", "Tauri App (Test)"),
                app_version: get_env("APP_VERSION", "1.0.0-beta"),
                api_base_url: get_env("API_BASE_URL", "http://192.168.1.100:8080/api"),
                api_timeout: get_env_u64("API_TIMEOUT", 15000),
                ws_url: get_env("WS_URL", "ws://192.168.1.100:9502"),
                ws_reconnect_interval: get_env_u64("WS_RECONNECT_INTERVAL", 5000),
                log_level: get_env("LOG_LEVEL", "info"),
                log_dir: log_dir.join("test"),
                enable_debug: true,
                enable_mock: false,
                enable_crash_report: true,
                db_host: get_env("DB_HOST", "192.168.1.100"),
                db_port: get_env_u16("DB_PORT", 3306),
                db_name: get_env("DB_NAME", "tauri_test"),
            },

            AppEnv::Prod => AppConfig {
                env,
                app_name: get_env("APP_NAME", "Tauri App"),
                app_version: get_env("APP_VERSION", "1.0.0"),
                api_base_url: get_env("API_BASE_URL", "https://api.example.com/api"),
                api_timeout: get_env_u64("API_TIMEOUT", 10000),
                ws_url: get_env("WS_URL", "wss://api.example.com/wss"),
                ws_reconnect_interval: get_env_u64("WS_RECONNECT_INTERVAL", 10000),
                log_level: get_env("LOG_LEVEL", "error"),
                log_dir: log_dir.join("prod"),
                enable_debug: false,
                enable_mock: false,
                enable_crash_report: true,
                db_host: get_env("DB_HOST", "db.example.com"),
                db_port: get_env_u16("DB_PORT", 3306),
                db_name: get_env("DB_NAME", "tauri_prod"),
            },
        }
    }

    /// 从 JSON 文件加载配置
    pub fn from_file(path: &PathBuf) -> Result<Self, String> {
        let content = fs::read_to_string(path)
            .map_err(|e| format!("Failed to read config file: {}", e))?;

        serde_json::from_str(&content)
            .map_err(|e| format!("Failed to parse config: {}", e))
    }

    /// 保存配置到文件
    pub fn to_file(&self, path: &PathBuf) -> Result<(), String> {
        let content = serde_json::to_string_pretty(self)
            .map_err(|e| format!("Failed to serialize config: {}", e))?;

        fs::write(path, content)
            .map_err(|e| format!("Failed to write config file: {}", e))
    }
}

/// 全局配置实例
use std::sync::OnceLock;
static CONFIG: OnceLock<AppConfig> = OnceLock::new();

pub fn init_config(env: AppEnv) -> &'static AppConfig {
    CONFIG.get_or_init(|| AppConfig::from_env(env))
}

pub fn get_config() -> &'static AppConfig {
    CONFIG.get().expect("Config not initialized")
}
```

### 4.3 Rust 命令接口

#### `src-tauri/src/commands.rs`

```rust
use crate::config::{AppConfig, AppEnv, get_config};
use tauri::State;
use std::sync::Mutex;

/// 配置状态
pub struct ConfigState(pub Mutex<AppConfig>);

/// 获取当前配置
#[tauri::command]
pub fn get_app_config(state: State<ConfigState>) -> Result<AppConfig, String> {
    let config = state.0.lock().map_err(|e| e.to_string())?;
    Ok(config.clone())
}

/// 获取环境信息
#[tauri::command]
pub fn get_env_info() -> Result<serde_json::Value, String> {
    let config = get_config();
    Ok(serde_json::json!({
        "env": config.env.as_str(),
        "appName": config.app_name,
        "version": config.app_version,
        "isDebug": config.enable_debug,
    }))
}

/// 更新配置
#[tauri::command]
pub fn update_config(
    state: State<ConfigState>,
    key: String,
    value: serde_json::Value,
) -> Result<(), String> {
    let mut config = state.0.lock().map_err(|e| e.to_string())?;

    match key.as_str() {
        "api_base_url" => {
            if let Some(v) = value.as_str() {
                config.api_base_url = v.to_string();
            }
        }
        "log_level" => {
            if let Some(v) = value.as_str() {
                config.log_level = v.to_string();
            }
        }
        "enable_debug" => {
            if let Some(v) = value.as_bool() {
                config.enable_debug = v;
            }
        }
        _ => return Err(format!("Unknown config key: {}", key)),
    }

    Ok(())
}

/// 切换环境
#[tauri::command]
pub fn switch_env(state: State<ConfigState>, env: String) -> Result<AppConfig, String> {
    let new_env = AppEnv::from_str(&env);
    let new_config = AppConfig::from_env(new_env);

    let mut config = state.0.lock().map_err(|e| e.to_string())?;
    *config = new_config.clone();

    Ok(new_config)
}
```

### 4.4 主入口文件

#### `src-tauri/src/lib.rs`

```rust
mod config;
mod commands;

use config::{AppConfig, AppEnv, ConfigState, init_config};
use commands::*;

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    // 从环境变量获取环境配置
    let env_str = std::env::var("TAURI_ENV")
        .unwrap_or_else(|_| "dev".to_string());
    let env = AppEnv::from_str(&env_str);

    // 初始化配置
    let config = init_config(env.clone());

    tauri::Builder::default()
        .plugin(tauri_plugin_log::Builder::new()
            .target(tauri_plugin_log::Target::new(
                tauri_plugin_log::TargetKind::LogDir { file_name: Some("app".into()) },
            ))
            .level(match config.log_level.as_str() {
                "trace" => log::LevelFilter::Trace,
                "debug" => log::LevelFilter::Debug,
                "info" => log::LevelFilter::Info,
                "warn" => log::LevelFilter::Warn,
                _ => log::LevelFilter::Error,
            }))
            .build())
        .plugin(tauri_plugin_shell::init())
        .plugin(tauri_plugin_dialog::init())
        .plugin(tauri_plugin_fs::init())
        .manage(ConfigState(std::sync::Mutex::new(config.clone())))
        .invoke_handler(tauri::generate_handler![
            get_app_config,
            get_env_info,
            update_config,
            switch_env,
        ])
        .setup(move |app| {
            log::info!("Application starting in {} mode", env.as_str());
            log::info!("API URL: {}", config.api_base_url);
            log::info!("Log level: {}", config.log_level);

            // 设置窗口标题
            if let Some(window) = app.get_webview_window("main") {
                let _ = window.set_title(&config.app_name);
            }

            Ok(())
        })
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
```

---

## 五、构建脚本方案

### 5.1 平台通用脚本

#### `scripts/build-env.sh`

```bash
#!/bin/bash

# ============================================
# Tauri 多环境构建脚本
# ============================================

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 项目根目录
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# 环境类型
ENV="${1:-dev}"

# 构建类型: debug | release
BUILD_TYPE="${2:-release}"

# 输出目录
OUTPUT_DIR="${PROJECT_ROOT}/dist-tauri"

# 颜色输出函数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 显示帮助
show_help() {
    cat << EOF
Tauri 多环境构建脚本

用法: ./scripts/build-env.sh <环境> [构建类型]

环境:
  dev     - 开发环境
  test    - 测试环境
  prod    - 正式环境

构建类型:
  debug   - 调试构建
  release - 发布构建（默认）

示例:
  ./scripts/build-env.sh dev release     # 构建开发环境的发布版
  ./scripts/build-env.sh test debug      # 构建测试环境的调试版
  ./scripts/build-env.sh prod release    # 构建正式环境的发布版

EOF
}

# 验证环境
validate_env() {
    case "$ENV" in
        dev|test|prod) return 0 ;;
        *)
            log_error "无效的环境: $ENV"
            echo "有效的环境: dev, test, prod"
            exit 1
            ;;
    esac
}

# 设置环境变量
setup_env() {
    log_info "设置 $ENV 环境变量..."

    export TAURI_ENV="$ENV"
    export NODE_ENV="production"

    # 根据环境设置不同的 API 地址
    case "$ENV" in
        dev)
            export VITE_API_BASE_URL="http://localhost:8080/api"
            export VITE_WS_URL="ws://localhost:9502"
            ;;
        test)
            export VITE_API_BASE_URL="http://192.168.1.100:8080/api"
            export VITE_WS_URL="ws://192.168.1.100:9502"
            ;;
        prod)
            export VITE_API_BASE_URL="https://api.example.com/api"
            export VITE_WS_URL="wss://api.example.com/wss"
            ;;
    esac
}

# 清理构建
clean_build() {
    log_info "清理构建目录..."
    cd "$PROJECT_ROOT"
    rm -rf dist
    rm -rf "$OUTPUT_DIR"
}

# 安装依赖
install_deps() {
    log_info "安装依赖..."
    cd "$PROJECT_ROOT"
    npm install
}

# 前端构建
build_frontend() {
    log_info "构建前端..."

    cd "$PROJECT_ROOT"

    if [ "$BUILD_TYPE" = "release" ]; then
        npm run build -- --mode "$ENV"
    else
        npm run build:dev
    fi
}

# Tauri 构建
build_tauri() {
    log_info "构建 Tauri (${BUILD_TYPE})..."

    cd "$PROJECT_ROOT"

    if [ "$BUILD_TYPE" = "release" ]; then
        npm run tauri:build
    else
        npm run tauri:build -- --debug
    fi
}

# 打包产物
package_output() {
    log_info "打包构建产物..."

    cd "$PROJECT_ROOT"

    # 创建环境特定的输出目录
    local env_output="${OUTPUT_DIR}/${ENV}"
    mkdir -p "$env_output"

    # 根据平台复制产物
    case "$(uname)" in
        Linux*)
            if [ -d "$PROJECT_ROOT/src-tauri/target/release/bundle/deb" ]; then
                cp -r "$PROJECT_ROOT/src-tauri/target/release/bundle/deb"/* "$env_output/"
            fi
            if [ -d "$PROJECT_ROOT/src-tauri/target/release/bundle/AppImage" ]; then
                cp -r "$PROJECT_ROOT/src-tauri/target/release/bundle/AppImage"/* "$env_output/"
            fi
            ;;
        Darwin*)
            if [ -d "$PROJECT_ROOT/src-tauri/target/release/bundle/dmg" ]; then
                cp -r "$PROJECT_ROOT/src-tauri/target/release/bundle/dmg"/* "$env_output/"
            fi
            if [ -d "$PROJECT_ROOT/src-tauri/target/release/bundle/macos" ]; then
                cp -r "$PROJECT_ROOT/src-tauri/target/release/bundle/macos"/* "$env_output/"
            fi
            ;;
        MINGW*|CYGWIN*|MSYS*)
            if [ -d "$PROJECT_ROOT/src-tauri/target/release/bundle/msi" ]; then
                cp -r "$PROJECT_ROOT/src-tauri/target/release/bundle/msi"/* "$env_output/"
            fi
            if [ -d "$PROJECT_ROOT/src-tauri/target/release/bundle/nsis" ]; then
                cp -r "$PROJECT_ROOT/src-tauri/target/release/bundle/nsis"/* "$env_output/"
            fi
            ;;
    esac

    # 复制前端产物
    cp -r "$PROJECT_ROOT/dist" "$env_output/"

    log_info "构建产物已保存到: $env_output"
}

# 显示结果
show_result() {
    log_info "==================================="
    log_info "构建完成!"
    log_info "环境: $ENV"
    log_info "类型: $BUILD_TYPE"
    log_info "产物目录: $OUTPUT_DIR/$ENV"
    log_info "==================================="
}

# 主函数
main() {
    if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
        show_help
        exit 0
    fi

    log_info "开始构建..."
    log_info "环境: $ENV, 类型: $BUILD_TYPE"

    validate_env
    setup_env
    clean_build
    install_deps
    build_frontend
    build_tauri
    package_output
    show_result
}

main "$@"
```

### 5.2 独立构建脚本

#### `scripts/build-dev.sh`

```bash
#!/bin/bash
cd "$(dirname "$0")/.."
./scripts/build-env.sh dev release
```

#### `scripts/build-test.sh`

```bash
#!/bin/bash
cd "$(dirname "$0")/.."
./scripts/build-env.sh test release
```

#### `scripts/build-prod.sh`

```bash
#!/bin/bash
cd "$(dirname "$0")/.."
./scripts/build-prod.sh
```

### 5.3 批量构建脚本

#### `scripts/build-all.sh`

```bash
#!/bin/bash

# ============================================
# 批量构建所有环境
# ============================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "========================================"
echo "批量构建所有环境"
echo "========================================"

# 依次构建开发、测试、正式环境
for env in dev test prod; do
    echo ""
    echo ">>> 构建 $env 环境..."
    "$SCRIPT_DIR/build-env.sh" "$env" release
done

echo ""
echo "========================================"
echo "所有环境构建完成!"
echo "产物目录: $PROJECT_ROOT/dist-tauri"
echo "========================================"

# 显示产物列表
ls -la "$PROJECT_ROOT/dist-tauri/"
```

### 5.4 Windows 批处理脚本

#### `scripts/build-dev.bat`

```batch
@echo off
setlocal

set PROJECT_ROOT=%~dp0..
cd /d %PROJECT_ROOT%

echo ========================================
echo Building Development Environment
echo ========================================

set TAURI_ENV=dev
set VITE_API_BASE_URL=http://localhost:8080/api

call npm install
call npm run build -- --mode dev
call npm run tauri:build

echo ========================================
echo Build Complete!
echo ========================================

endlocal
```

---

## 六、package.json 配置

### `package.json`

```json
{
  "name": "tauri-multi-env-app",
  "version": "1.0.0",
  "private": true,
  "type": "module",
  "scripts": {
    "dev": "vite",
    "dev:dev": "vite --mode dev",
    "dev:test": "vite --mode test",
    "dev:prod": "vite --mode prod",

    "build": "vue-tsc && vite build",
    "build:dev": "vue-tsc && vite build --mode dev",
    "build:test": "vue-tsc && vite build --mode test",
    "build:prod": "vue-tsc && vite build --mode prod",

    "preview": "vite preview",

    "tauri": "tauri",
    "tauri:dev": "tauri dev",
    "tauri:dev:dev": "TAURI_ENV=dev tauri dev",
    "tauri:dev:test": "TAURI_ENV=test tauri dev",
    "tauri:dev:prod": "TAURI_ENV=prod tauri dev",
    "tauri:build": "tauri build",
    "tauri:build:dev": "TAURI_ENV=dev tauri build",
    "tauri:build:test": "TAURI_ENV=test tauri build",
    "tauri:build:prod": "TAURI_ENV=prod tauri build",

    "build:all:dev": "node scripts/build-env.js dev release",
    "build:all:test": "node scripts/build-env.js test release",
    "build:all:prod": "node scripts/build-env.js prod release"
  },
  "dependencies": {
    "@tauri-apps/api": "^2.0.0",
    "@tauri-apps/plugin-dialog": "^2.0.0",
    "@tauri-apps/plugin-fs": "^2.0.0",
    "@tauri-apps/plugin-log": "^2.0.0",
    "@tauri-apps/plugin-shell": "^2.0.0",
    "vue": "^3.4.0"
  },
  "devDependencies": {
    "@tauri-apps/cli": "^2.0.0",
    "@vitejs/plugin-vue": "^5.0.0",
    "typescript": "^5.3.0",
    "vite": "^5.0.0",
    "vue-tsc": "^1.8.0"
  }
}
```

### `vite.config.ts`

```typescript
import { defineConfig } from 'vite';
import vue from '@vitejs/plugin-vue';
import { resolve } from 'path';

export default defineConfig(({ mode }) => {
  // 从环境变量加载
  const envFile = `.env.${mode}`;

  return {
    plugins: [vue()],

    // 环境变量文件
    envDir: './',

    // 替换变量
    define: {
      __APP_ENV__: JSON.stringify(mode),
    },

    resolve: {
      alias: {
        '@': resolve(__dirname, 'src'),
      },
    },

    build: {
      outDir: 'dist',
      sourcemap: mode !== 'prod',
      minify: mode === 'prod' ? 'esbuild' : false,

      // Rollup 配置
      rollupOptions: {
        output: {
          // 分环境打包
          entryFileNames: `assets/[name]-${mode}.[hash].js`,
          chunkFileNames: `assets/[name]-${mode}.[hash].js`,
          assetFileNames: `assets/[name]-${mode}.[hash].[ext]`,
        },
      },
    },

    // 开发服务器配置
    server: {
      port: 5173,
      strictPort: true,
    },

    // 日志
    logLevel: mode === 'prod' ? 'warn' : 'info',
  };
});
```

---

## 七、CI/CD 集成

### GitHub Actions 示例

#### `.github/workflows/build.yml`

```yaml
name: Build Tauri App

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]
  workflow_dispatch:
    inputs:
      environment:
        description: 'Build Environment'
        required: true
        default: 'dev'
        type: choice
        options:
          - dev
          - test
          - prod

jobs:
  build:
    strategy:
      fail-fast: false
      matrix:
        platform: [macos-latest, ubuntu-latest, windows-latest]
        include:
          - platform: macos-latest
            rust_target: 'aarch64-apple-darwin'
          - platform: ubuntu-latest
            rust_target: 'x86_64-unknown-linux-gnu'
          - platform: windows-latest
            rust_target: 'x86_64-pc-windows-msvc'

    runs-on: ${{ matrix.platform }}

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'

      - name: Setup Rust
        uses: dtolnay/rust-toolchain@stable
        with:
          target: ${{ matrix.rust_target }}

      - name: Cache Rust
        uses: Swatinem/rust-cache@v2
        with:
          workspaces: './src-tauri -> target'

      - name: Install dependencies
        run: npm ci

      - name: Build Tauri App
        env:
          TAURI_ENV: ${{ inputs.environment || 'dev' }}
        run: |
          if [ "$TAURI_ENV" = "prod" ]; then
            npm run tauri:build:prod
          elif [ "$TAURI_ENV" = "test" ]; then
            npm run tauri:build:test
          else
            npm run tauri:build:dev
          fi

      - name: Upload artifacts
        uses: actions/upload-artifact@v4
        with:
          name: tauri-app-${{ matrix.platform }}-${{ inputs.environment || 'dev' }}
          path: |
            src-tauri/target/release/bundle/**
            !src-tauri/target/**/deps/**
            !src-tauri/target/**/incremental/**
          retention-days: 30
```

---

## 八、使用指南

### 快速开始

```bash
# 克隆项目
git clone https://github.com/example/tauri-app.git
cd tauri-app

# 安装依赖
npm install

# 开发环境开发
npm run dev:dev
npm run tauri:dev:dev

# 构建
npm run build:all:dev    # 开发版
npm run build:all:test   # 测试版
npm run build:all:prod   # 正式版

# 或使用脚本
./scripts/build-dev.sh
./scripts/build-test.sh
./scripts/build-prod.sh
```

### 切换环境

**方式一：命令行**
```bash
TAURI_ENV=prod npm run tauri:dev
```

**方式二：修改 .env 文件**
```bash
# .env
TAURI_ENV=prod
```

**方式三：运行时切换**
```typescript
// 在应用中切换
import { invoke } from '@tauri-apps/api/core';

const newConfig = await invoke('switch_env', { env: 'prod' });
```

---

## 九、配置对比速查表

| 配置项 | 开发环境 | 测试环境 | 正式环境 |
|--------|----------|----------|----------|
| API 地址 | localhost:8080 | 192.168.1.100 | api.example.com |
| 日志级别 | debug | info | error |
| 调试功能 | 开启 | 开启 | 关闭 |
| 模拟数据 | 开启 | 关闭 | 关闭 |
| 崩溃报告 | 关闭 | 开启 | 开启 |
| 自动更新 | 关闭 | 开启 | 开启 |
| 控制台日志 | 开启 | 开启 | 关闭 |
| WebSocket | ws://localhost | ws://192.168.1.100 | wss://api.example.com |

---

*文档版本: 1.0.0*
*更新日期: 2026-04-27*
