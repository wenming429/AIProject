# Content Security Policy (CSP) 安全策略详解

## 1. CSP 如何阻止内联脚本和样式

### 1.1 内联脚本/样式的风险

**什么是内联脚本？**
```html
<!-- 内联脚本 -->
<script>alert('XSS')</script>

<!-- 内联样式 -->
<div style="color: red">红色文字</div>

<!-- 内联事件处理器 -->
<div onclick="maliciousCode()">点击我</div>
```

**为什么危险？**
攻击者可以通过 XSS（跨站脚本攻击）注入恶意代码：

```html
<!-- 恶意用户输入 -->
用户名: <script>stealCookies()</script>
<!-- 或者 -->
<img src=x onerror="stealPasswords()">
```

如果网站允许内联脚本，攻击者的代码会被执行。

### 1.2 CSP 如何阻止

**默认阻止内联脚本：**
```http
Content-Security-Policy: script-src 'self'
```
此时 `<script>alert('XSS')</script>` 会被阻止。

**阻止内联样式：**
```http
Content-Security-Policy: style-src 'self'
```
此时 `<div style="color: red">` 会被阻止。

### 1.3 nonce 和 hash 的作用

**nonce（一次性数字）：**
```html
<!-- 服务器生成随机 nonce -->
<script nonce="abc123">alert('安全')</script>
```
```http
Content-Security-Policy: script-src 'nonce-abc123'
```

**hash（内容指纹）：**
```html
<script>alert('安全')</script>
```
```http
Content-Security-Policy: script-src 'sha256-abcdef...'
```

## 2. unsafe-inline 与 nonce 的冲突

### 2.1 问题原因

```
style-src 'self' 'unsafe-inline' 'nonce-7776904659601365290'
```

**根据 CSP 规范：** 当 `nonce-*` 出现在 `style-src` 中时，`'unsafe-inline'` 会被忽略。

这意味着：
- ✅ 带有正确 `nonce` 属性的内联样式会被允许
- ❌ 普通的 `<style>` 标签会被阻止
- ❌ `style="..."` 属性会被阻止

### 2.2 解决方案

**方案一：移除 nonce，只用 unsafe-inline（简单但不够安全）**
```http
Content-Security-Policy: style-src 'self' 'unsafe-inline'
```

**方案二：使用 hash（安全但不够灵活）**
```http
Content-Security-Policy: style-src 'self' 'sha256-xxxxx'
```
需要为每个内联样式计算 hash。

**方案三：为 Vue 组件样式启用外部加载**

Vite/Vue 项目中，scoped 样式会被编译成 CSS 文件引用：
```html
<link rel="stylesheet" href="/assets/login.abc123.css">
```

配置 CSP 允许加载外部 CSS：
```http
Content-Security-Policy: style-src 'self' 'unsafe-inline' data: blob: asset:
```

## 3. 移动内联代码到外部文件

### 3.1 将内联脚本移到外部文件

**原代码（不安全）：**
```html
<script>alert('Hello')</script>
```

**修改后（安全）：**
```javascript
// static/js/hello.js
function sayHello() {
  alert('Hello');
}
```
```html
<script src="/static/js/hello.js"></script>
```

### 3.2 将内联样式移到外部文件

**原代码（不安全）：**
```html
<style>.red { color: red; }</style>
```

**修改后（安全）：**
```css
/* static/css/styles.css */
.red { color: red; }
```
```html
<link rel="stylesheet" href="/static/css/styles.css">
```

### 3.3 将事件处理器移到 JavaScript

**原代码（不安全）：**
```html
<button onclick="doSomething()">点击</button>
```

**修改后（安全）：**
```javascript
// static/js/main.js
document.getElementById('myButton').addEventListener('click', doSomething);
```
```html
<button id="myButton">点击</button>
<script src="/static/js/main.js"></script>
```

## 4. LumenIM 项目的 CSP 配置

### 4.1 当前配置

```json
{
  "security": {
    "csp": "default-src 'self' http://localhost:*; 
            script-src 'self' 'unsafe-inline' 'unsafe-eval'; 
            style-src 'self' 'unsafe-inline' data: blob: asset:; 
            img-src 'self' data: blob: asset: http://localhost:*; 
            font-src 'self' data:; 
            connect-src 'self' ipc: http://localhost:* https://* ws://localhost:* wss://localhost:* ws://* wss://*; 
            frame-src 'self' blob:; 
            media-src 'self' blob: http://localhost:*; 
            object-src 'self' blob:"
  }
}
```

### 4.2 配置说明

| 指令 | 值 | 说明 |
|------|-----|------|
| `default-src` | `'self' http://localhost:*` | 默认来源 |
| `script-src` | `'self' 'unsafe-inline' 'unsafe-eval'` | 脚本来源（允许内联和 eval） |
| `style-src` | `'self' 'unsafe-inline' data: blob: asset:` | 样式来源（允许内联、data URI、blob、asset） |
| `img-src` | `'self' data: blob: asset: http://localhost:*` | 图片来源 |
| `font-src` | `'self' data:` | 字体来源 |
| `connect-src` | `'self' ipc: http://localhost:* ...` | AJAX/WebSocket 来源 |

### 4.3 修复登录界面样式

**问题原因：**
`style-src` 中缺少 `data:` `blob:` `asset:` 支持，导致外部 CSS 文件无法加载。

**修复方案：**
```diff
- style-src 'self' 'unsafe-inline'
+ style-src 'self' 'unsafe-inline' data: blob: asset:
```

## 5. 安全建议

### 5.1 推荐的 CSP 配置（生产环境）

```http
Content-Security-Policy: 
  default-src 'self';
  script-src 'self';
  style-src 'self' 'sha256-xxxxx';
  img-src 'self' data: https:;
  font-src 'self';
  connect-src 'self' https://api.example.com;
  frame-ancestors 'none';
  base-uri 'self';
  form-action 'self'
```

### 5.2 Vue 项目特殊处理

Vue/Vite 项目中：
- Scoped 样式会被编译成独立的 CSS 文件
- 使用 hash 模式时，需要更新所有样式 hash
- 建议保持 `'unsafe-inline'` 以简化开发

### 5.3 检测 XSS 漏洞

使用 CSP 报告模式：
```http
Content-Security-Policy-Report-Only: style-src 'self'; report-uri /csp-report
```

## 6. 总结

| 方案 | 安全性 | 维护性 | 适用场景 |
|------|--------|--------|----------|
| `'unsafe-inline'` | 低 | 高 | 开发环境、快速原型 |
| nonce | 高 | 中 | 服务器渲染页面 |
| hash | 高 | 低 | 静态页面、固定内容 |
| 外部文件 | 高 | 高 | 生产环境最佳实践 |

**LumenIM 项目建议：**
- 开发/测试环境：使用 `'unsafe-inline'` + `'unsafe-eval'`
- 生产环境：移除 `'unsafe-eval'`，考虑使用 hash 或 nonce
