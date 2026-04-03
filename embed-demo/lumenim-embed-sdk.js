/**
 * LumenIM 嵌入式聊天窗口 JavaScript SDK
 * 用于将 LumenIM 聊天功能集成到第三方系统（如OA、CRM等）
 * 
 * @version 1.0.0
 * @author LumenIM Team
 * @license MIT
 * 
 * 样式与 FloatingChat.vue 保持一致
 */

(function(global, factory) {
  if (typeof module === 'object' && typeof module.exports === 'object') {
    module.exports = factory();
  } else if (typeof define === 'function' && define.amd) {
    define(factory);
  } else {
    global.LumenIMEmbed = factory();
  }
})(this, function() {
  'use strict';

  /**
   * 默认配置 - 与 FloatingChat.vue 默认值保持一致
   */
  const DEFAULT_CONFIG = {
    // LumenIM 服务地址
    serverUrl: 'http://localhost:5173',
    // 嵌入页面路径
    embedPath: '/#/embed',
    // 容器ID
    containerId: 'lumenim-chat-container',
    // 按钮ID
    buttonId: 'lumenim-chat-button',
    // 初始位置（悬浮窗模式）
    position: {
      bottom: 80,
      right: 30
    },
    // 窗口尺寸 - 与 FloatingChat.vue 一致
    size: {
      width: 800,
      height: 600
    },
    // 最小尺寸 - 与 FloatingChat.vue 一致
    minSize: {
      width: 600,
      height: 400
    },
    // 是否允许拖拽
    draggable: true,
    // 是否允许调整大小
    resizable: true,
    // 主题：'light-gray' | 'china-red'
    theme: 'light-gray',
    // 自动登录Token（可选）
    authToken: null,
    // 调试模式
    debug: false
  };

  /**
   * LumenIM 嵌入类 - 样式与 FloatingChat.vue 保持一致
   */
  class LumenIMEmbed {
    constructor(options = {}) {
      this.config = Object.assign({}, DEFAULT_CONFIG, options);
      this.isOpen = false;
      this.isMinimized = false;
      this.listeners = new Map();
      this.iframe = null;
      this.container = null;
      this.button = null;
      this.dragState = null;
      
      // 窗口位置
      this.windowPosition = {
        x: Math.max(20, (window.innerWidth - this.config.size.width) / 2),
        y: Math.max(20, (window.innerHeight - this.config.size.height) / 2)
      };
      
      // 初始化
      this.init();
    }

    /**
     * 日志输出
     */
    log(...args) {
      if (this.config.debug) {
        console.log('[LumenIM]', ...args);
      }
    }

    /**
     * 错误输出
     */
    error(...args) {
      console.error('[LumenIM]', ...args);
    }

    /**
     * 初始化
     */
    init() {
      this.log('Initializing LumenIM Embed SDK...');
      
      // 检查是否已初始化
      if (document.getElementById(this.config.containerId)) {
        this.error('Container already exists');
        return;
      }

      // 创建容器
      this.createContainer();
      
      // 创建悬浮按钮
      this.createButton();
      
      // 监听消息
      this.setupMessageListener();
      
      // 监听窗口大小变化
      this.setupResizeListener();
      
      // 监听键盘事件
      this.setupKeyboardListener();
      
      this.log('Initialized successfully');
      
      // 触发就绪事件
      this.emit('ready');
    }

    /**
     * 创建容器 - 与 FloatingChat.vue 窗口结构一致
     */
    createContainer() {
      const container = document.createElement('div');
      container.id = this.config.containerId;
      container.className = 'lumenim-embed-container';
      container.style.cssText = `
        position: fixed;
        left: ${this.windowPosition.x}px;
        top: ${this.windowPosition.y}px;
        width: ${this.config.size.width}px;
        height: ${this.config.size.height}px;
        min-width: ${this.config.minSize.width}px;
        min-height: ${this.config.minSize.height}px;
        background: #ffffff;
        border-radius: 8px;
        box-shadow: 0 8px 32px rgba(0,0,0,0.15);
        z-index: 9999;
        display: none;
        flex-direction: column;
        overflow: hidden;
      `;
      
      // 添加调整大小手柄 - 与 FloatingChat.vue 一致
      container.innerHTML = `
        <div class="lumenim-embed-resize-handle lumenim-resize-n" data-resize="n"></div>
        <div class="lumenim-embed-resize-handle lumenim-resize-e" data-resize="e"></div>
        <div class="lumenim-embed-resize-handle lumenim-resize-s" data-resize="s"></div>
        <div class="lumenim-embed-resize-handle lumenim-resize-w" data-resize="w"></div>
        <div class="lumenim-embed-resize-handle lumenim-resize-ne" data-resize="ne"></div>
        <div class="lumenim-embed-resize-handle lumenim-resize-nw" data-resize="nw"></div>
        <div class="lumenim-embed-resize-handle lumenim-resize-se" data-resize="se"></div>
        <div class="lumenim-embed-resize-handle lumenim-resize-sw" data-resize="sw"></div>
        
        <div class="lumenim-embed-window-content">
          <!-- 左侧功能菜单栏 - 华夏红主题 -->
          <aside class="lumenim-embed-sidebar">
            <!-- 用户头像 -->
            <div class="lumenim-embed-sidebar-header">
              <div class="lumenim-embed-avatar-wrapper">
                <div class="lumenim-embed-avatar">
                  <svg width="36" height="36" viewBox="0 0 24 24" fill="none">
                    <path d="M12 12c2.21 0 4-1.79 4-4s-1.79-4-4-4-4 1.79-4 4 1.79 4 4 4zm0 2c-2.67 0-8 1.34-8 4v2h16v-2c0-2.66-5.33-4-8-4z" fill="currentColor"/>
                  </svg>
                </div>
                <div class="lumenim-embed-online-indicator"></div>
              </div>
            </div>
            
            <!-- 导航菜单 -->
            <nav class="lumenim-embed-sidebar-nav">
              <div class="lumenim-embed-nav-item active" data-page="message" title="消息">
                <svg width="22" height="22" viewBox="0 0 24 24" fill="none">
                  <path d="M20 2H4C2.9 2 2 2.9 2 4V22L6 18H20C21.1 18 22 17.1 22 16V4C22 2.9 21.1 2 20 2ZM20 16H6L4 18V4H20V16Z" fill="currentColor"/>
                </svg>
              </div>
              <div class="lumenim-embed-nav-item" data-page="contact" title="通讯录">
                <svg width="22" height="22" viewBox="0 0 24 24" fill="none">
                  <path d="M16 11c1.66 0 2.99-1.34 2.99-3S17.66 5 16 5c-1.66 0-3 1.34-3 3s1.34 3 3 3zm-8 0c1.66 0 2.99-1.34 2.99-3S9.66 5 8 5C6.34 5 5 6.34 5 8s1.34 3 3 3zm0 2c-2.33 0-7 1.17-7 3.5V19h14v-2.5c0-2.33-4.67-3.5-7-3.5zm8 0c-.29 0-.62.02-.97.05 1.16.84 1.97 1.97 1.97 3.45V19h6v-2.5c0-2.33-4.67-3.5-7-3.5z" fill="currentColor"/>
                </svg>
              </div>
              <div class="lumenim-embed-nav-item" data-page="apps" title="应用">
                <svg width="22" height="22" viewBox="0 0 24 24" fill="none">
                  <path d="M4 8h4V4H4v4zm6 12h4v-4h-4v4zm-6 0h4v-4H4v4zm0-6h4v-4H4v4zm6 0h4v-4h-4v4zm6-10v4h4V4h-4zm-6 4h4V4h-4v4zm6 6h4v-4h-4v4zm0 6h4v-4h-4v4z" fill="currentColor"/>
                </svg>
              </div>
            </nav>
            
            <!-- 底部设置 -->
            <div class="lumenim-embed-sidebar-footer">
              <div class="lumenim-embed-nav-item" data-page="settings" title="设置">
                <svg width="22" height="22" viewBox="0 0 24 24" fill="none">
                  <path d="M19.14 12.94c.04-.31.06-.63.06-.94 0-.31-.02-.63-.06-.94l2.03-1.58c.18-.14.23-.41.12-.61l-1.92-3.32c-.12-.22-.37-.29-.59-.22l-2.39.96c-.5-.38-1.03-.7-1.62-.94l-.36-2.54c-.04-.24-.24-.41-.48-.41h-3.84c-.24 0-.43.17-.47.41l-.36 2.54c-.59.24-1.13.57-1.62.94l-2.39-.96c-.22-.08-.47 0-.59.22L2.74 8.87c-.12.21-.08.47.12.61l2.03 1.58c-.04.31-.06.63-.06.94s.02.63.06.94l-2.03 1.58c-.18.14-.23.41-.12.61l1.92 3.32c.12.22.37.29.59.22l2.39-.96c.5.38 1.03.7 1.62.94l.36 2.54c.05.24.24.41.48.41h3.84c.24 0 .44-.17.47-.41l.36-2.54c.59-.24 1.13-.56 1.62-.94l2.39.96c.22.08.47 0 .59-.22l1.92-3.32c.12-.22.07-.47-.12-.61l-2.01-1.58zM12 15.6c-1.98 0-3.6-1.62-3.6-3.6s1.62-3.6 3.6-3.6 3.6 1.62 3.6 3.6-1.62 3.6-3.6 3.6z" fill="currentColor"/>
                </svg>
              </div>
            </div>
          </aside>
          
          <!-- 中间会话列表 -->
          <aside class="lumenim-embed-session-list">
            <!-- 会话列表内容由 iframe 内部提供 -->
          </aside>
          
          <!-- 右侧内容区域 -->
          <main class="lumenim-embed-chat-area">
            <div class="lumenim-embed-header">
              <div class="lumenim-embed-title-wrapper">
                <span class="lumenim-embed-title">消息</span>
              </div>
              <div class="lumenim-embed-controls">
                <button class="lumenim-embed-btn-minimize" title="最小化">
                  <svg width="14" height="14" viewBox="0 0 24 24" fill="#fff">
                    <path d="M19 13H5v-2h14v2z"/>
                  </svg>
                </button>
                <button class="lumenim-embed-btn-close" title="关闭">
                  <svg width="14" height="14" viewBox="0 0 24 24" fill="#fff">
                    <path d="M19 6.41L17.59 5 12 10.59 6.41 5 5 6.41 10.59 12 5 17.59 6.41 19 12 13.41 17.59 19 19 17.59 13.41 12z"/>
                  </svg>
                </button>
              </div>
            </div>
            <div class="lumenim-embed-body">
              <iframe 
                src="${this.config.serverUrl}${this.config.embedPath}"
                class="lumenim-embed-iframe"
                allow="microphone; camera"
                sandbox="allow-same-origin allow-scripts allow-popups allow-forms"
              ></iframe>
            </div>
          </main>
        </div>
      `;
      
      // 添加样式
      this.addStyles();
      
      // 绑定事件
      const minimizeBtn = container.querySelector('.lumenim-embed-btn-minimize');
      const closeBtn = container.querySelector('.lumenim-embed-btn-close');
      const header = container.querySelector('.lumenim-embed-header');
      
      minimizeBtn.addEventListener('click', () => this.minimize());
      closeBtn.addEventListener('click', () => this.close());
      
      // 拖拽
      if (this.config.draggable) {
        header.addEventListener('mousedown', (e) => this.startDrag(e));
      }
      
      // 调整大小
      if (this.config.resizable) {
        const resizeHandles = container.querySelectorAll('.lumenim-embed-resize-handle');
        resizeHandles.forEach(handle => {
          handle.addEventListener('mousedown', (e) => this.startResize(e, handle.dataset.resize));
        });
      }
      
      // 导航菜单点击
      const navItems = container.querySelectorAll('.lumenim-embed-nav-item');
      navItems.forEach(item => {
        item.addEventListener('click', () => {
          navItems.forEach(i => i.classList.remove('active'));
          item.classList.add('active');
          const page = item.dataset.page;
          this.postMessage('navigate', { page });
        });
      });
      
      document.body.appendChild(container);
      this.container = container;
      this.iframe = container.querySelector('.lumenim-embed-iframe');
    }

    /**
     * 创建悬浮按钮 - 华夏红主题，与 FloatingChat.vue 一致
     */
    createButton() {
      const button = document.createElement('div');
      button.id = this.config.buttonId;
      button.className = 'lumenim-embed-button';
      button.innerHTML = `
        <svg viewBox="0 0 24 24" fill="none">
          <path d="M20 2H4C2.9 2 2 2.9 2 4V22L6 18H20C21.1 18 22 17.1 22 16V4C22 2.9 21.1 2 20 2ZM20 16H6L4 18V4H20V16Z" fill="white"/>
          <path d="M7 9H17V11H7V9ZM7 12H14V14H7V12Z" fill="white"/>
        </svg>
        <span class="lumenim-embed-badge" style="display:none">0</span>
      `;
      
      button.addEventListener('click', () => this.open());
      
      // 拖拽按钮
      let isDragging = false;
      let startPos = { x: 0, y: 0 };
      
      button.addEventListener('mousedown', (e) => {
        if (e.target.closest('.lumenim-embed-badge')) return;
        
        isDragging = false;
        startPos = { x: e.clientX, y: e.clientY };
        
        const onMouseMove = (e) => {
          const dx = e.clientX - startPos.x;
          const dy = e.clientY - startPos.y;
          
          if (Math.abs(dx) > 5 || Math.abs(dy) > 5) {
            isDragging = true;
          }
          
          if (isDragging) {
            button.style.left = (e.clientX - 30) + 'px';
            button.style.top = (e.clientY - 30) + 'px';
            button.style.right = 'auto';
            button.style.bottom = 'auto';
          }
        };
        
        const onMouseUp = () => {
          document.removeEventListener('mousemove', onMouseMove);
          document.removeEventListener('mouseup', onMouseUp);
        };
        
        document.addEventListener('mousemove', onMouseMove);
        document.addEventListener('mouseup', onMouseUp);
      });
      
      document.body.appendChild(button);
      this.button = button;
    }

    /**
     * 添加样式 - 与 FloatingChat.vue 样式保持一致
     */
    addStyles() {
      if (document.getElementById('lumenim-embed-styles')) return;
      
      const style = document.createElement('style');
      style.id = 'lumenim-embed-styles';
      style.textContent = `
        /* 容器 */
        .lumenim-embed-container {
          pointer-events: auto;
        }
        
        .lumenim-embed-container.active {
          display: flex;
        }
        
        /* 调整大小手柄 - 与 FloatingChat.vue 一致 */
        .lumenim-embed-resize-handle {
          position: absolute;
          z-index: 10;
        }

        .lumenim-resize-n {
          top: 0;
          left: 10px;
          right: 10px;
          height: 6px;
          cursor: ns-resize;
        }

        .lumenim-resize-e {
          top: 10px;
          right: 0;
          bottom: 10px;
          width: 6px;
          cursor: ew-resize;
        }

        .lumenim-resize-s {
          bottom: 0;
          left: 10px;
          right: 10px;
          height: 6px;
          cursor: ns-resize;
        }

        .lumenim-resize-w {
          top: 10px;
          left: 0;
          bottom: 10px;
          width: 6px;
          cursor: ew-resize;
        }

        .lumenim-resize-ne {
          top: 0;
          right: 0;
          width: 10px;
          height: 10px;
          cursor: nesw-resize;
        }

        .lumenim-resize-nw {
          top: 0;
          left: 0;
          width: 10px;
          height: 10px;
          cursor: nwse-resize;
        }

        .lumenim-resize-se {
          bottom: 0;
          right: 0;
          width: 10px;
          height: 10px;
          cursor: nwse-resize;
        }

        .lumenim-resize-sw {
          bottom: 0;
          left: 0;
          width: 10px;
          height: 10px;
          cursor: nesw-resize;
        }
        
        /* 窗口内容布局 */
        .lumenim-embed-window-content {
          flex: 1;
          display: flex;
          overflow: hidden;
        }
        
        /* 左侧功能菜单栏 - 华夏红主题 */
        .lumenim-embed-sidebar {
          width: 60px;
          background: linear-gradient(180deg, #BF0008 0%, #D4000A 100%);
          display: flex;
          flex-direction: column;
          align-items: center;
          padding: 12px 0;
          flex-shrink: 0;
        }
        
        .lumenim-embed-sidebar-header {
          margin-bottom: 16px;
        }
        
        .lumenim-embed-avatar-wrapper {
          position: relative;
        }
        
        .lumenim-embed-avatar {
          width: 36px;
          height: 36px;
          border-radius: 50%;
          background: rgba(255,255,255,0.2);
          display: flex;
          align-items: center;
          justify-content: center;
          color: white;
          border: 2px solid rgba(255,255,255,0.5);
        }
        
        .lumenim-embed-online-indicator {
          position: absolute;
          bottom: 2px;
          right: 2px;
          width: 8px;
          height: 8px;
          border-radius: 50%;
          background: #10B981;
          border: 2px solid #BF0008;
        }
        
        .lumenim-embed-sidebar-nav {
          flex: 1;
          display: flex;
          flex-direction: column;
          gap: 4px;
        }
        
        .lumenim-embed-sidebar-footer {
          margin-top: auto;
          padding-top: 12px;
        }
        
        .lumenim-embed-nav-item {
          width: 44px;
          height: 44px;
          display: flex;
          align-items: center;
          justify-content: center;
          border-radius: 8px;
          cursor: pointer;
          position: relative;
          transition: all 0.2s;
          color: rgba(255,255,255,0.7);
        }
        
        .lumenim-embed-nav-item:hover {
          background: rgba(255,255,255,0.1);
        }
        
        .lumenim-embed-nav-item.active {
          background: rgba(255,255,255,0.2);
          color: white;
        }
        
        .lumenim-embed-nav-item.active::before {
          content: '';
          position: absolute;
          left: 0;
          top: 50%;
          transform: translateY(-50%);
          width: 3px;
          height: 18px;
          background: white;
          border-radius: 0 2px 2px 0;
        }
        
        /* 中间会话列表 */
        .lumenim-embed-session-list {
          width: 260px;
          background: #fafafa;
          border-right: 1px solid #e8e8e8;
          display: flex;
          flex-direction: column;
          flex-shrink: 0;
          overflow: hidden;
        }
        
        /* 右侧内容区域 */
        .lumenim-embed-chat-area {
          flex: 1;
          display: flex;
          flex-direction: column;
          min-width: 0;
          background: #ffffff;
        }
        
        .lumenim-embed-header {
          height: 48px;
          background: #f5f5f5;
          border-bottom: 1px solid #e8e8e8;
          display: flex;
          align-items: center;
          justify-content: space-between;
          padding: 0 16px;
          cursor: move;
          user-select: none;
          flex-shrink: 0;
        }
        
        .lumenim-embed-title-wrapper {
          display: flex;
          align-items: center;
          gap: 8px;
        }
        
        .lumenim-embed-title {
          font-size: 14px;
          color: #333;
          font-weight: 500;
        }
        
        .lumenim-embed-controls {
          display: flex;
          gap: 8px;
        }
        
        .lumenim-embed-btn-minimize,
        .lumenim-embed-btn-close {
          width: 28px;
          height: 28px;
          border-radius: 4px;
          border: none;
          background: transparent;
          display: flex;
          align-items: center;
          justify-content: center;
          cursor: pointer;
          transition: background 0.2s;
        }
        
        .lumenim-embed-btn-minimize:hover,
        .lumenim-embed-btn-close:hover {
          background: rgba(0,0,0,0.1);
        }
        
        .lumenim-embed-btn-close:hover {
          background: #ff4757;
        }
        
        .lumenim-embed-body {
          flex: 1;
          overflow: hidden;
        }
        
        .lumenim-embed-iframe {
          width: 100%;
          height: 100%;
          border: none;
        }
        
        /* 悬浮按钮 - 华夏红主题 */
        .lumenim-embed-button {
          position: fixed;
          bottom: 80px;
          right: 30px;
          width: 60px;
          height: 60px;
          border-radius: 50%;
          background: linear-gradient(135deg, #BF0008 0%, #D4000A 100%);
          box-shadow: 0 4px 20px rgba(191, 0, 8, 0.4), 0 0 0 3px rgba(255,255,255,0.2);
          cursor: pointer;
          display: flex;
          align-items: center;
          justify-content: center;
          z-index: 9998;
          transition: all 0.3s ease;
          user-select: none;
        }
        
        .lumenim-embed-button:hover {
          transform: scale(1.05);
          box-shadow: 0 6px 24px rgba(191, 0, 8, 0.5), 0 0 0 4px rgba(255,255,255,0.25);
        }
        
        .lumenim-embed-button:active {
          cursor: grabbing;
          transform: scale(0.98);
        }
        
        .lumenim-embed-button svg {
          width: 28px;
          height: 28px;
        }
        
        /* 未读徽章 */
        .lumenim-embed-badge {
          position: absolute;
          top: -5px;
          right: -5px;
          min-width: 20px;
          height: 20px;
          padding: 0 6px;
          background: #ff4757;
          color: white;
          font-size: 12px;
          font-weight: 600;
          border-radius: 10px;
          display: flex;
          align-items: center;
          justify-content: center;
          box-shadow: 0 2px 8px rgba(255, 71, 87, 0.4);
        }
        
        /* 响应式 */
        @media (max-width: 768px) {
          .lumenim-embed-container {
            top: 0 !important;
            left: 0 !important;
            right: 0 !important;
            bottom: 0 !important;
            width: 100% !important;
            height: 100% !important;
            min-width: 100% !important;
            min-height: 100% !important;
            border-radius: 0;
          }
          
          .lumenim-embed-session-list {
            width: 200px;
          }
          
          .lumenim-embed-button {
            width: 50px;
            height: 50px;
            bottom: 20px;
            right: 20px;
          }
          
          .lumenim-embed-button svg {
            width: 24px;
            height: 24px;
          }
        }
      `;
      
      document.head.appendChild(style);
    }

    /**
     * 设置消息监听
     */
    setupMessageListener() {
      window.addEventListener('message', (e) => {
        // 验证来源
        const allowedOrigins = [this.config.serverUrl];
        if (!allowedOrigins.includes(e.origin)) return;
        
        const { type, data } = e.data || {};
        
        this.log('Received message:', type, data);
        
        switch(type) {
          case 'ready':
            this.postMessage('init', {
              theme: this.config.theme,
              authToken: this.config.authToken
            });
            break;
            
          case 'unread-count':
            this.updateBadge(data.count);
            this.emit('unreadCount', data.count);
            break;
            
          case 'new-message':
            this.emit('newMessage', data);
            break;
            
          case 'close':
            this.close();
            break;
            
          case 'error':
            this.error('Iframe error:', data);
            this.emit('error', data);
            break;
        }
        
        this.emit('message', { type, data });
      });
    }

    /**
     * 设置窗口大小监听
     */
    setupResizeListener() {
      let resizeTimer = null;
      
      window.addEventListener('resize', () => {
        clearTimeout(resizeTimer);
        resizeTimer = setTimeout(() => {
          this.adjustPosition();
        }, 250);
      });
    }

    /**
     * 设置键盘监听
     */
    setupKeyboardListener() {
      document.addEventListener('keydown', (e) => {
        if (e.key === 'Escape' && this.isOpen) {
          this.close();
        }
      });
    }

    /**
     * 调整位置（确保在可视区域内）
     */
    adjustPosition() {
      if (!this.container || !this.isOpen) return;
      
      const rect = this.container.getBoundingClientRect();
      const viewportWidth = window.innerWidth;
      const viewportHeight = window.innerHeight;
      
      let { width, height } = rect;
      let left = parseInt(this.container.style.left) || (viewportWidth - width) / 2;
      let top = parseInt(this.container.style.top) || (viewportHeight - height) / 2;
      
      left = Math.max(0, Math.min(left, viewportWidth - width));
      top = Math.max(0, Math.min(top, viewportHeight - height));
      
      this.container.style.left = left + 'px';
      this.container.style.top = top + 'px';
    }

    /**
     * 开始拖拽
     */
    startDrag(e) {
      if (e.target.closest('.lumenim-embed-controls')) return;
      
      this.dragState = {
        startX: e.clientX,
        startY: e.clientY,
        startLeft: parseInt(this.container.style.left) || this.container.offsetLeft,
        startTop: parseInt(this.container.style.top) || this.container.offsetTop
      };
      
      document.addEventListener('mousemove', this.onDragMove);
      document.addEventListener('mouseup', this.onDragEnd);
    }

    /**
     * 拖拽移动
     */
    onDragMove = (e) => {
      if (!this.dragState) return;
      
      const dx = e.clientX - this.dragState.startX;
      const dy = e.clientY - this.dragState.startY;
      
      this.container.style.left = (this.dragState.startLeft + dx) + 'px';
      this.container.style.top = (this.dragState.startTop + dy) + 'px';
    };

    /**
     * 拖拽结束
     */
    onDragEnd = () => {
      this.dragState = null;
      document.removeEventListener('mousemove', this.onDragMove);
      document.removeEventListener('mouseup', this.onDragEnd);
    };

    /**
     * 开始调整大小
     */
    startResize(e, direction) {
      e.preventDefault();
      e.stopPropagation();
      
      this.resizeState = {
        startX: e.clientX,
        startY: e.clientY,
        startWidth: this.container.offsetWidth,
        startHeight: this.container.offsetHeight,
        startLeft: parseInt(this.container.style.left) || 0,
        startTop: parseInt(this.container.style.top) || 0,
        direction
      };
      
      document.addEventListener('mousemove', this.onResizeMove);
      document.addEventListener('mouseup', this.onResizeEnd);
    }

    /**
     * 调整大小移动
     */
    onResizeMove = (e) => {
      if (!this.resizeState) return;
      
      const { startX, startY, startWidth, startHeight, startLeft, startTop, direction } = this.resizeState;
      const dx = e.clientX - startX;
      const dy = e.clientY - startY;
      
      let newWidth = startWidth;
      let newHeight = startHeight;
      let newLeft = startLeft;
      let newTop = startTop;
      
      if (direction.includes('e')) {
        newWidth = Math.max(this.config.minSize.width, startWidth + dx);
      }
      if (direction.includes('w')) {
        const tempWidth = Math.max(this.config.minSize.width, startWidth - dx);
        if (tempWidth !== newWidth) {
          newLeft = startLeft + startWidth - tempWidth;
          newWidth = tempWidth;
        }
      }
      if (direction.includes('s')) {
        newHeight = Math.max(this.config.minSize.height, startHeight + dy);
      }
      if (direction.includes('n')) {
        const tempHeight = Math.max(this.config.minSize.height, startHeight - dy);
        if (tempHeight !== newHeight) {
          newTop = startTop + startHeight - tempHeight;
          newHeight = tempHeight;
        }
      }
      
      this.container.style.width = newWidth + 'px';
      this.container.style.height = newHeight + 'px';
      this.container.style.left = newLeft + 'px';
      this.container.style.top = newTop + 'px';
    };

    /**
     * 调整大小结束
     */
    onResizeEnd = () => {
      this.resizeState = null;
      document.removeEventListener('mousemove', this.onResizeMove);
      document.removeEventListener('mouseup', this.onResizeEnd);
    };

    /**
     * 发送消息到 iframe
     */
    postMessage(type, data) {
      if (!this.iframe || !this.iframe.contentWindow) {
        this.error('Iframe not ready');
        return;
      }
      
      this.iframe.contentWindow.postMessage({
        type,
        data,
        timestamp: Date.now()
      }, this.config.serverUrl);
    }

    /**
     * 更新未读徽章
     */
    updateBadge(count) {
      const badge = this.button.querySelector('.lumenim-embed-badge');
      if (count > 0) {
        badge.textContent = count > 99 ? '99+' : count;
        badge.style.display = 'flex';
      } else {
        badge.style.display = 'none';
      }
    }

    /**
     * 打开聊天窗口
     */
    open() {
      this.log('Opening chat window');
      
      this.isOpen = true;
      this.isMinimized = false;
      
      this.container.classList.add('active');
      this.button.style.display = 'none';
      
      this.emit('open');
    }

    /**
     * 关闭聊天窗口
     */
    close() {
      this.log('Closing chat window');
      
      this.isOpen = false;
      this.isMinimized = false;
      
      this.container.classList.remove('active');
      this.button.style.display = 'flex';
      
      this.emit('close');
    }

    /**
     * 最小化
     */
    minimize() {
      this.log('Minimizing chat window');
      
      this.isMinimized = true;
      this.isOpen = false;
      
      this.container.classList.remove('active');
      this.button.style.display = 'flex';
      
      this.emit('minimize');
    }

    /**
     * 切换到消息页面
     */
    switchToMessage() {
      this.postMessage('navigate', { page: 'message' });
    }

    /**
     * 切换到通讯录
     */
    switchToContact() {
      this.postMessage('navigate', { page: 'contact' });
    }

    /**
     * 打开指定会话
     */
    openConversation(type, id) {
      this.postMessage('conversation', { type, id });
      this.open();
    }

    /**
     * 设置主题
     */
    setTheme(theme) {
      this.config.theme = theme;
      this.postMessage('theme', { theme });
    }

    /**
     * 销毁实例
     */
    destroy() {
      this.log('Destroying instance');
      
      if (this.container) {
        this.container.remove();
        this.container = null;
      }
      
      if (this.button) {
        this.button.remove();
        this.button = null;
      }
      
      const style = document.getElementById('lumenim-embed-styles');
      if (style) style.remove();
      
      this.emit('destroy');
    }

    /**
     * 事件监听
     */
    on(event, callback) {
      if (!this.listeners.has(event)) {
        this.listeners.set(event, []);
      }
      this.listeners.get(event).push(callback);
      return this;
    }

    /**
     * 取消监听
     */
    off(event, callback) {
      const callbacks = this.listeners.get(event);
      if (callbacks) {
        const index = callbacks.indexOf(callback);
        if (index > -1) callbacks.splice(index, 1);
      }
      return this;
    }

    /**
     * 触发事件
     */
    emit(event, data) {
      const callbacks = this.listeners.get(event);
      if (callbacks) {
        callbacks.forEach(cb => {
          try {
            cb(data);
          } catch (err) {
            this.error('Event callback error:', err);
          }
        });
      }
    }
  }

  return LumenIMEmbed;
});
