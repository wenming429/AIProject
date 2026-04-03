# LumenIM 嵌入式聊天窗口集成方案

将 LumenIM 即时通讯功能无缝集成到现有 OA/CRM/ERP 系统的完整解决方案。

## 📋 目录

- [快速开始](#快速开始)
- [集成方式](#集成方式)
- [文件说明](#文件说明)
- [配置选项](#配置选项)
- [API 文档](#api-文档)
- [跨域处理](#跨域处理)
- [响应式适配](#响应式适配)
- [常见问题](#常见问题)

## 🚀 快速开始

### 方式一：使用 JavaScript SDK（推荐）

```html
<!-- 1. 引入 SDK -->
<script src="lumenim-embed-sdk.js"></script>

<script>
// 2. 一行代码初始化
const chat = new LumenIMEmbed({
  serverUrl: 'https://im.yourcompany.com',
  theme: 'light-gray'  // 或 'china-red'
});
</script>
```

### 方式二：使用 iframe 直接嵌入

```html
<!-- 悬浮按钮 -->
<div class="chat-float-btn" onclick="toggleChat()">💬</div>

<!-- 聊天窗口 -->
<div id="chat-container" class="chat-iframe-container">
  <iframe src="https://im.yourcompany.com/#/embed"></iframe>
</div>
```

## 📦 文件说明

| 文件 | 说明 |
|------|------|
| `lumenim-embed-sdk.js` | JavaScript SDK，提供完整 API |
| `quick-start.html` | 快速开始示例页面 |
| `oa-integration-demo.html` | 完整 OA 系统集成演示 |
| `README.md` | 本文档 |

## 🔌 集成方式

### 1. 悬浮弹窗模式（默认）

聊天窗口悬浮在页面右下角，可拖拽移动、调整大小。使用华夏红主题，与 FloatingChat.vue 样式保持一致。

```javascript
const chat = new LumenIMEmbed({
  serverUrl: 'https://im.yourcompany.com',
  position: { bottom: 80, right: 30 },
  size: { width: 800, height: 600 },
  minSize: { width: 600, height: 400 }
});
```

### 2. 右侧边栏模式

将聊天窗口嵌入右侧边栏，与 OA 系统布局融合。

```html
<style>
.sidebar-chat-panel {
  position: fixed;
  top: 60px;
  right: 0;
  width: 380px;
  height: calc(100vh - 60px);
}
</style>

<div class="sidebar-chat-panel">
  <iframe src="https://im.yourcompany.com/#/embed"></iframe>
</div>
```

### 3. 底部面板模式

在页面底部显示聊天面板，适合宽屏使用。

```html
<style>
.bottom-chat-panel {
  position: fixed;
  bottom: 0;
  left: 240px;
  right: 0;
  height: 400px;
}
</style>
```

## ⚙️ 配置选项

### 完整配置示例

```javascript
const chat = new LumenIMEmbed({
  // 服务器配置
  serverUrl: 'https://im.yourcompany.com',  // 必填
  embedPath: '/#/embed',                     // 嵌入页面路径
  
  // 外观配置
  theme: 'light-gray',                       // 主题：'light-gray' | 'china-red'
  position: { bottom: 30, right: 30 },       // 悬浮按钮位置
  size: { width: 900, height: 600 },         // 窗口尺寸
  minSize: { width: 400, height: 400 },      // 最小尺寸
  
  // 功能配置
  draggable: true,                           // 允许拖拽
  resizable: true,                           // 允许调整大小
  
  // 认证配置
  authToken: 'user-jwt-token',               // 自动登录Token
  
  // 调试配置
  debug: false                               // 调试模式
});
```

## 📡 API 文档

### 方法

| 方法 | 参数 | 返回值 | 说明 |
|------|------|--------|------|
| `open()` | - | - | 打开聊天窗口 |
| `close()` | - | - | 关闭聊天窗口 |
| `minimize()` | - | - | 最小化窗口 |
| `switchToMessage()` | - | - | 切换到消息页面 |
| `switchToContact()` | - | - | 切换到通讯录 |
| `openConversation(type, id)` | type: 'user'\|'group', id: string | - | 打开指定会话 |
| `setTheme(theme)` | theme: string | - | 切换主题 |
| `destroy()` | - | - | 销毁实例 |

### 事件

```javascript
// 监听未读消息数变化
chat.on('unreadCount', (count) => {
  console.log('未读消息:', count);
});

// 监听新消息
chat.on('newMessage', (message) => {
  console.log('新消息:', message);
});

// 监听窗口打开/关闭
chat.on('open', () => console.log('窗口已打开'));
chat.on('close', () => console.log('窗口已关闭'));

// 监听就绪事件
chat.on('ready', () => console.log('SDK 已就绪'));
```

### 取消监听

```javascript
const handler = (count) => console.log(count);
chat.on('unreadCount', handler);
chat.off('unreadCount', handler);  // 取消监听
```

## 🌐 跨域处理

### 方案 A：CORS 配置（推荐）

在 LumenIM 服务端配置允许的域名：

```go
// Go 后端示例
func corsMiddleware() gin.HandlerFunc {
  return func(c *gin.Context) {
    allowedOrigins := []string{
      "https://oa.company.com",
      "https://crm.company.com",
    }
    
    origin := c.GetHeader("Origin")
    for _, allowed := range allowedOrigins {
      if origin == allowed {
        c.Header("Access-Control-Allow-Origin", origin)
        break
      }
    }
    
    c.Header("Access-Control-Allow-Credentials", "true")
    c.Next()
  }
}
```

### 方案 B：反向代理

通过 Nginx 统一域名，避免跨域：

```nginx
server {
  listen 80;
  server_name oa.company.com;
  
  location / {
    proxy_pass http://oa-backend;
  }
  
  location /im/ {
    proxy_pass http://im-backend/;
  }
  
  location /chat/ {
    proxy_pass http://im-frontend/embed;
  }
}
```

### 方案 C：单点登录 (SSO)

```javascript
// OA 系统登录后设置共享 Cookie
document.cookie = 'sso_token=xxx; domain=.company.com; path=/';

// LumenIM 初始化时读取
const chat = new LumenIMEmbed({
  serverUrl: 'https://im.company.com',
  authToken: getCookie('sso_token')  // 自动登录
});
```

## 📱 响应式适配

SDK 自动适配不同设备：

| 设备 | 宽度 | 布局模式 | 特点 |
|------|------|----------|------|
| 桌面端 | ≥1200px | 悬浮窗 | 可拖拽、可调整大小 |
| 平板 | 768-1199px | 侧边栏 | 常驻显示 |
| 手机 | <768px | 全屏 | 沉浸式体验 |

```javascript
// 手动检测并切换模式
window.addEventListener('resize', () => {
  const width = window.innerWidth;
  if (width < 768) {
    // 切换到移动端模式
  }
});
```

## ❓ 常见问题

### Q1: 如何自动登录？

```javascript
const chat = new LumenIMEmbed({
  serverUrl: 'https://im.company.com',
  authToken: 'your-jwt-token'  // 从 OA 系统获取
});
```

### Q2: 如何与 OA 系统共享用户信息？

通过 postMessage 通信：

```javascript
// OA 系统发送用户信息
chat.postMessage('userInfo', {
  id: '123',
  name: '张三',
  avatar: 'https://...'
});
```

### Q3: 如何处理样式冲突？

SDK 使用 Shadow DOM 和 CSS 命名空间隔离样式：

```css
/* SDK 所有样式都有前缀 */
.lumenim-embed-container { }
.lumenim-embed-button { }
.lumenim-embed-header { }
```

### Q4: 如何自定义主题颜色？

```javascript
// 使用内置主题
chat.setTheme('light-gray');  // 浅灰
chat.setTheme('china-red');   // 华夏红

// 或自定义 CSS 变量
document.documentElement.style.setProperty('--im-primary-color', '#your-color');
```

### Q5: 移动端如何优化？

SDK 自动检测移动端并切换到全屏模式。如需自定义：

```javascript
const chat = new LumenIMEmbed({
  serverUrl: 'https://im.company.com',
  size: window.innerWidth < 768 
    ? { width: '100%', height: '100%' }  // 移动端全屏
    : { width: 900, height: 600 }         // 桌面端窗口
});
```

## 🔒 安全建议

1. **验证消息来源**：始终验证 postMessage 的 origin
2. **使用 HTTPS**：生产环境必须使用 HTTPS
3. **Token 安全**：JWT Token 设置合理过期时间
4. **iframe 沙箱**：使用 sandbox 属性限制权限
5. **CORS 白名单**：严格限制允许的域名

## 📞 技术支持

- 文档：https://docs.lumenim.com
- 问题反馈：https://github.com/lumenim/lumenim/issues
- 邮箱：support@lumenim.com

## 📄 许可证

MIT License

---

**LumenIM** - 企业级即时通讯解决方案
