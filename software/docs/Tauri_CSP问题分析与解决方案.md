# Tauri CSP 问题分析与解决方案总结

## 📋 问题概述

### 错误信息
```
Content Security Policy blocks inline execution of scripts and stylesheets
Content Security Policy of your site blocks some resources
Applying inline style violates the following Content Security Policy directive
'style-src 'self' 'unsafe-inline' 'nonce-XXXXXXXXXXXXXXXX''
```

### 问题本质
Tauri 桌面应用运行时内联样式/脚本被 CSP 阻止。

---

## 🔍 问题根因分析

### 1. CSP nonce 机制原理

| 概念 | 说明 |
|------|------|
| **配置文件** (`tauri.conf.json`) | 构建时读取 |
| **Nonce 值** | 由 Rust 宏 `generate_context!()` 在编译时**动态生成** |
| **编译产物（二进制）** | 包含生成时的 nonce，无法通过修改配置文件更新 |

**关键结论**：修改 `tauri.conf.json` 后**必须重新编译 Rust 代码**才能生效。

### 2. 常见错误配置

#### 错误：nonce 与 unsafe-inline 混用
```json
"csp": "... style-src 'self' 'unsafe-inline' 'nonce-*'; ..."
```
**问题**：当 `'nonce-*'` 存在时，浏览器会**忽略** `'unsafe-inline'`

#### 错误：缺少 unsafe-hashes
```json
"csp": "... style-src 'self' 'unsafe-inline' data: blob: asset:; ..."
```
**问题**：只允许 `<style>` 标签的内联样式，但**不允许** `style="..."` 属性形式

#### 错误：缺少精细化 CSP 指令
```json
"csp": "... style-src 'self' 'unsafe-inline'; ..."
```
**问题**：缺少 `style-src-elem` 和 `style-src-attr` 控制不同类型的样式

### 3. 问题排查流程

```
1. 检查 tauri.conf.json 配置
   └─ style-src 是否包含 'unsafe-inline'、'unsafe-hashes'、data: blob: asset:
   └─ 是否同时存在 'nonce-*' 或 hash（与 unsafe-inline 冲突）

2. 检查运行的是否为最新构建
   └─ 旧编译产物仍包含旧的 nonce
   └─ 解决方案：重新构建

3. 检查所有环境配置文件
   └─ tauri.conf.json
   └─ tauri.conf.local.json
   └─ tauri.conf.test.json
   └─ tauri.conf.prod.json
   └─ build-tauri.bat 脚本模板
```

---

## ✅ 解决方案

### 1. 正确的 CSP 配置模板

```json
{
  "security": {
    "csp": "default-src 'self' http://localhost:* https://*; \
            script-src 'self' 'unsafe-inline' 'unsafe-eval' http://localhost:* https://*; \
            style-src 'self' 'unsafe-inline' 'unsafe-hashes' data: blob: asset: http://localhost:* https://*; \
            style-src-elem 'self' 'unsafe-inline' data: blob: asset: http://localhost:* https://*; \
            style-src-attr 'self' 'unsafe-inline' 'unsafe-hashes' data: blob:; \
            img-src 'self' data: blob: asset: http://localhost:* https://*; \
            font-src 'self' data: http://localhost:* https://*; \
            connect-src 'self' ipc: http://localhost:* https://* ws://localhost:* wss://localhost:* ws://* wss://*; \
            frame-src 'self' blob:; \
            media-src 'self' blob: http://localhost:* https://*; \
            object-src 'self' blob:; \
            base-uri 'self'; \
            form-action 'self'"
  }
}
```

### 2. CSP 指令说明

| 指令 | 用途 | 必需值 |
|------|------|--------|
| `default-src` | 默认资源来源 | `'self'` |
| `script-src` | JS 脚本来源 | `'unsafe-inline'` `'unsafe-eval'` |
| `style-src` | CSS 样式来源 | `'unsafe-inline'` `'unsafe-hashes'` `data:` `blob:` `asset:` |
| `style-src-elem` | `<style>` 元素和 CSS 文件 | `'unsafe-inline'` `data:` `blob:` |
| `style-src-attr` | 内联样式属性 `style="..."` | `'unsafe-inline'` `'unsafe-hashes'` |
| `img-src` | 图片来源 | `data:` `blob:` `asset:` |
| `font-src` | 字体来源 | `data:` |
| `connect-src` | API 请求来源 | `ipc:` `ws:` `wss:` |
| `base-uri` | `<base>` 标签限制 | `'self'` |
| `form-action` | 表单提交目标 | `'self'` |

### 3. 多环境配置同步

需要同步更新的文件：

| 文件 | 说明 |
|------|------|
| `front/src-tauri/tauri.conf.json` | 主配置 |
| `front/src-tauri/tauri.conf.local.json` | 本地开发环境 |
| `front/src-tauri/tauri.conf.test.json` | 测试环境 |
| `front/src-tauri/tauri.conf.prod.json` | 生产环境 |
| `software/scripts/build-tauri.bat` | 构建脚本模板 |

### 4. 构建脚本 CSP 模板（build-tauri.bat）

```batch
set "CSP=default-src 'self' %CSP_ALLOW_HOSTS% https://*; script-src 'self' 'unsafe-inline' 'unsafe-eval' %CSP_ALLOW_HOSTS% https://*; style-src 'self' 'unsafe-inline' 'unsafe-hashes' data: blob: asset: %CSP_ALLOW_HOSTS% https://*; style-src-elem 'self' 'unsafe-inline' data: blob: asset: %CSP_ALLOW_HOSTS% https://*; style-src-attr 'self' 'unsafe-inline' 'unsafe-hashes' data: blob:; img-src 'self' data: blob: asset: %CSP_ALLOW_HOSTS% https://*; font-src 'self' data: %CSP_ALLOW_HOSTS% https://*; connect-src 'self' ipc: %CSP_ALLOW_HOSTS% https://* %CSP_ALLOW_WS% ws://* wss://*; frame-src 'self' blob:; media-src 'self' blob: %CSP_ALLOW_HOSTS% https://*; object-src 'self' blob:; base-uri 'self'; form-action 'self'"
```

---

## 🔧 验证与修复流程

### 步骤 1：检查配置文件
```batch
# 检查 tauri.conf.json 中的 style-src
findstr "style-src" front\src-tauri\tauri.conf.json
```

**正确输出示例**：
```
style-src 'self' 'unsafe-inline' 'unsafe-hashes' data: blob: asset:
```

**错误输出示例**：
```
style-src 'self' 'unsafe-inline' 'nonce-*'
```

### 步骤 2：清理并重新构建
```batch
# 方案一：完整构建
cd software\scripts
build-local.bat

# 方案二：只清理 Rust 缓存后构建
cd front\src-tauri
cargo clean
cd ..\..\software\scripts
build-local.bat
```

### 步骤 3：验证二进制
```batch
# 检查编译后的二进制文件路径
dir front\src-tauri\target\release\lumenim-desktop.exe
```

### 步骤 4：重启应用
**重要**：构建完成后必须**完全关闭**旧应用，重新启动新构建的版本。

---

## ⚠️ 常见问题与解答

### Q1：修改配置后问题依旧？
**A**：运行的是旧编译产物，必须重新构建。

### Q2：为什么 nonce 会自动生成？
**A**：Tauri 2.x 默认启用 `generate_context!()` 宏的 nonce 生成功能。需确保配置文件中不包含 `nonce-*`。

### Q3：unsafe-inline 是否安全？
**A**：`'unsafe-inline'` 允许内联脚本/样式，存在 XSS 风险。但在桌面应用场景下风险可控，因为：
- 应用运行在本地环境
- 无浏览器扩展介入
- 资源来源可控

如需更严格的安全策略，可考虑使用 hash 验证替代。

### Q4：生产环境是否需要相同配置？
**A**：生产环境可适当收紧：
- 将 `http://localhost:*` 替换为具体域名
- 移除 `ws://* wss://*` 的通配符
- 保持 `unsafe-inline` 和 `unsafe-hashes` 以支持框架运行

---

## 📊 问题解决检查清单

| 步骤 | 检查项 | 状态 |
|------|--------|------|
| 1 | `tauri.conf.json` 中 style-src 包含 `'unsafe-inline'` `'unsafe-hashes'` | ☐ |
| 2 | `tauri.conf.json` 中不存在 `'nonce-*'` | ☐ |
| 3 | 所有环境配置文件已同步更新 | ☐ |
| 4 | `build-tauri.bat` 脚本模板已更新 | ☐ |
| 5 | 执行 `cargo clean` 清理旧缓存 | ☐ |
| 6 | 执行 `build-local.bat` 重新构建 | ☐ |
| 7 | 完全关闭旧应用，启动新构建 | ☐ |

---

## 📝 后续优化建议

1. **CI/CD 集成**：在构建流程中自动验证 CSP 配置
2. **配置检查脚本**：构建前检查配置文件是否包含必要指令
3. **安全审计**：定期审查 `unsafe-inline` 和 `unsafe-eval` 的必要性
4. **文档维护**：更新团队文档，记录 CSP 配置规范

---

*文档更新时间：2026-04-28*
*适用版本：Tauri 2.x*
