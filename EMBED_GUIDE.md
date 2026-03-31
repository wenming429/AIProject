# 悬浮聊天窗口嵌入指南

## 概述

LumenIM 现在支持以悬浮窗口模式嵌入到任何网页中，提供即时通讯功能而不占用页面空间。

## 功能特性

- ✅ **悬浮球快捷入口**：页面右下角的悬浮球，带有未读消息徽章
- ✅ **可拖拽窗口**：聊天窗口可以拖拽到屏幕任意位置
- ✅ **完整聊天功能**：支持单聊、群聊、消息发送、图片/文件分享等
- ✅ **最小化/关闭**：支持最小化到悬浮球或完全关闭
- ✅ **未读消息提醒**：悬浮球上显示未读消息数量（最多显示 99+）
- ✅ **响应式设计**：适配不同屏幕尺寸
- ✅ **主题一致**：与应用整体风格保持一致

## 集成方式

### 方式一：通过路由访问（推荐）

访问 `/embed` 路径即可获得纯净的嵌入页面，只显示悬浮球：

```
https://your-domain.com/embed
```

### 方式二：通过 iframe 嵌入

在你的网站中添加以下代码：

```html
<iframe
  src="https://your-domain.com/embed"
  style="position: fixed; bottom: 0; right: 0; width: 0; height: 0; border: none;"
  id="lumenim-chat">
</iframe>
```

### 方式三：完整页面集成

如果你想在自己的页面中使用完整应用，同时启用悬浮球，正常访问应用即可。悬浮球会在登录后自动显示。

## API 控制

提供了全局 API 来控制悬浮窗口的显示：

```javascript
// 打开悬浮窗口（展开聊天窗口）
window.floatingChat.open()

// 关闭悬浮窗口（回到悬浮球状态）
window.floatingChat.close()
```

## 自定义配置

### 修改窗口大小

编辑 `src/components/chat/FloatingChat.vue`：

```javascript
const windowSize = ref({
  width: 400,  // 窗口宽度
  height: 550   // 窗口高度
})
```

### 修改初始位置

```javascript
const windowPosition = ref({
  x: window.innerWidth - 420,  // 距离左侧的像素
  y: window.innerHeight - 600  // 距离顶部的像素
})
```

### 自定义颜色

在 `FloatingChat.vue` 的 style 部分：

```less
// 悬浮球颜色
background: linear-gradient(135deg, #8B0000 0%, #a52a2a 100%);

// 窗口头部颜色
background: linear-gradient(135deg, #8B0000 0%, #a52a2a 100%);

// 徽章颜色
background: #ff4757;
```

## 使用示例

### 示例 1：简单嵌入

```html
<!DOCTYPE html>
<html>
<head>
  <title>我的网站</title>
</head>
<body>
  <h1>欢迎来到我的网站</h1>
  <p>这是网站内容...</p>

  <!-- 嵌入 LumenIM 聊天 -->
  <iframe
    src="https://your-domain.com/embed"
    style="position: fixed; bottom: 0; right: 0; width: 0; height: 0; border: none;">
  </iframe>
</body>
</html>
```

### 示例 2：带自定义控制

```html
<!DOCTYPE html>
<html>
<head>
  <title>我的网站</title>
</head>
<body>
  <h1>欢迎来到我的网站</h1>
  
  <!-- 联系我们按钮，点击打开聊天窗口 -->
  <button onclick="openChat()">联系我们</button>

  <iframe
    src="https://your-domain.com/embed"
    style="position: fixed; bottom: 0; right: 0; width: 0; height: 0; border: none;">
  </iframe>

  <script>
    function openChat() {
      // 延迟一点确保 iframe 加载完成
      setTimeout(() => {
        const iframe = document.querySelector('iframe');
        iframe.contentWindow.floatingChat?.open();
      }, 100);
    }
  </script>
</body>
</html>
```

## 注意事项

1. **登录要求**：悬浮球只在用户登录后显示，未登录时看不到悬浮球
2. **跨域限制**：如果通过 iframe 嵌入，确保服务器配置了正确的 CORS 头
3. **Cookie 共享**：确保嵌入页面和主域名共享 Cookie，否则无法保持登录状态
4. **HTTPS**：生产环境建议使用 HTTPS 协议
5. **窗口层级**：悬浮窗口使用 `z-index: 9999`，确保显示在最上层

## 测试

启动开发服务器：

```bash
cd front
pnpm run dev
```

访问以下 URL 测试：

- 完整应用：http://localhost:5173
- 嵌入页面：http://localhost:5173/embed

## 构建部署

构建生产版本：

```bash
cd front
pnpm run build
```

构建完成后，将 `dist` 目录部署到你的服务器即可。

## 技术栈

- Vue 3
- TypeScript
- Naive UI
- Vue Router
- Pinia

## 问题反馈

如有问题或建议，请在 GitHub 上提交 Issue。
