/**
 * LumenIM Electron 预加载脚本 - 增强版
 * 安全地暴露 Electron API 给渲染进程
 */
const { contextBridge, ipcRenderer } = require('electron')

// 日志工具
const logger = {
  info: (msg) => console.log(`[Preload] ${msg}`),
  error: (msg) => console.error(`[Preload] ${msg}`)
}

// 暴露 API 给渲染进程
contextBridge.exposeInMainWorld('$electron', {
  // ==================== 平台信息 ====================
  platform: process.platform,
  isMac: process.platform === 'darwin',
  isWindows: process.platform === 'win32',
  isLinux: process.platform === 'linux',

  // ==================== 窗口控制 ====================
  window: {
    /** 最小化窗口 */
    minimize: () => ipcRenderer.invoke('minimize-window'),
    
    /** 最大化/还原窗口 */
    maximize: () => ipcRenderer.invoke('maximize-window'),
    
    /** 关闭窗口 */
    close: () => ipcRenderer.invoke('close-window'),
    
    /** 隐藏窗口 */
    hide: () => ipcRenderer.invoke('hide-window'),
    
    /** 显示窗口 */
    show: () => ipcRenderer.invoke('show-window'),
    
    /** 是否最大化 */
    isMaximized: () => ipcRenderer.invoke('is-maximized'),
    
    /** 设置全屏 */
    setFullScreen: (fullscreen) => ipcRenderer.invoke('set-full-screen', fullscreen),
    
    /** 获取全屏状态 */
    isFullScreen: () => ipcRenderer.invoke('get-full-screen')
  },

  // ==================== 应用信息 ====================
  app: {
    /** 获取应用信息 */
    getInfo: () => ipcRenderer.invoke('get-app-info'),
    
    /** 退出应用 */
    quit: () => ipcRenderer.invoke('quit-app'),
    
    /** 重启应用 */
    relaunch: () => ipcRenderer.invoke('relaunch-app'),
    
    /** 切换开发者工具 */
    toggleDevTools: () => ipcRenderer.invoke('toggle-dev-tools')
  },

  // ==================== 通知系统 ====================
  notification: {
    /** 设置任务栏徽章数 */
    setBadge: (count) => ipcRenderer.invoke('set-badge', count),
    
    /** 显示系统通知 */
    show: (options) => ipcRenderer.invoke('show-notification', options)
  },

  // ==================== 外部链接 ====================
  shell: {
    /** 打开外部链接 */
    openExternal: (url) => ipcRenderer.invoke('open-external', url)
  },

  // ==================== 配置管理 ====================
  config: {
    /** 获取配置 */
    get: () => ipcRenderer.invoke('get-config'),
    
    /** 设置配置项 */
    set: (key, value) => ipcRenderer.invoke('set-config', key, value)
  },

  // ==================== 缓存管理 ====================
  cache: {
    /** 获取缓存路径 */
    getPath: () => ipcRenderer.invoke('get-cache-path'),
    
    /** 清除缓存 */
    clear: () => ipcRenderer.invoke('clear-cache')
  },

  // ==================== 下载管理 ====================
  download: {
    /** 获取下载路径 */
    getPath: () => ipcRenderer.invoke('get-download-path'),
    
    /** 设置下载路径 */
    setPath: (path) => ipcRenderer.invoke('set-download-path', path)
  },

  // ==================== 事件监听 ====================
  on: {
    /** 监听窗口最大化状态变化 */
    maximizeChange: (callback) => {
      const handler = () => callback()
      ipcRenderer.on('window-maximize', handler)
      return () => ipcRenderer.removeListener('window-maximize', handler)
    },

    /** 监听打开设置事件 */
    openSettings: (callback) => {
      const handler = () => callback()
      ipcRenderer.on('open-settings', handler)
      return () => ipcRenderer.removeListener('open-settings', handler)
    },

    /** 监听新建消息事件 */
    newMessage: (callback) => {
      const handler = () => callback()
      ipcRenderer.on('new-message', handler)
      return () => ipcRenderer.removeListener('new-message', handler)
    }
  }
})

// 暴露版本信息
contextBridge.exposeInMainWorld('$versions', {
  app: '1.0.0',
  electron: process.versions.electron,
  chrome: process.versions.chrome,
  node: process.versions.node,
  v8: process.versions.v8
})

// DOM 加载完成后的初始化
window.addEventListener('DOMContentLoaded', () => {
  logger.info('DOM content loaded')
  
  // 添加桌面端标识
  document.body.classList.add('is-desktop')
  document.body.classList.add(`platform-${process.platform}`)
  
  // 替换版本信息占位符
  const replaceText = (selector, text) => {
    const element = document.getElementById(selector)
    if (element) element.textContent = text
  }

  replaceText('electron-version', process.versions.electron)
  replaceText('chrome-version', process.versions.chrome)
  replaceText('node-version', process.versions.node)
})

logger.info('Preload script loaded')
