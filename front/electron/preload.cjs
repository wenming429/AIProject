/**
 * LumenIM Electron 预加载脚本
 * 通过 contextBridge 安全地暴露 Electron API 给渲染进程
 */
const { contextBridge, ipcRenderer } = require('electron')

// 暴露 API 给渲染进程
contextBridge.exposeInMainWorld('$electron', {
  // ============= 窗口控制 =============
  /** 获取全屏状态 */
  getFullScreenStatus: () => ipcRenderer.invoke('get-full-screen'),

  /** 设置全屏模式 */
  setFullScreen: (fullscreen) => ipcRenderer.invoke('set-full-screen', fullscreen),

  /** 获取最小化状态 */
  getMinimized: () => ipcRenderer.invoke('get-minimized'),

  /** 最小化窗口 */
  minimizeWindow: () => ipcRenderer.invoke('minimize-window'),

  /** 最大化/还原窗口 */
  maximizeWindow: () => ipcRenderer.invoke('maximize-window'),

  /** 获取最大化状态 */
  isMaximized: () => ipcRenderer.invoke('is-maximized'),

  /** 关闭窗口 */
  closeWindow: () => ipcRenderer.invoke('close-window'),

  /** 隐藏窗口 */
  hideWindow: () => ipcRenderer.invoke('hide-window'),

  /** 显示窗口 */
  showWindow: () => ipcRenderer.invoke('show-window'),

  // ============= 应用信息 =============
  /** 获取应用信息 */
  getAppInfo: () => ipcRenderer.invoke('get-app-info'),

  /** 获取本地 IP */
  getLocalIP: () => ipcRenderer.invoke('get-local-ip'),

  // ============= 通知与徽章 =============
  /** 设置任务栏徽章（未读消息数） */
  setBadge: (count) => ipcRenderer.invoke('set-badge', count),

  /** 显示系统通知 */
  showNotification: (options) => ipcRenderer.invoke('show-notification', options),

  // ============= 外部链接 =============
  /** 打开外部链接 */
  openExternal: (url) => ipcRenderer.invoke('open-external', url),

  // ============= 本地存储 =============
  /** 获取配置 */
  getConfig: () => ipcRenderer.invoke('get-config'),

  /** 设置配置 */
  setConfig: (key, value) => ipcRenderer.invoke('set-config', key, value),

  /** 获取缓存路径 */
  getCachePath: () => ipcRenderer.invoke('get-cache-path'),

  /** 清除缓存 */
  clearCache: () => ipcRenderer.invoke('clear-cache'),

  // ============= 事件监听 =============
  /** 监听全屏状态变化 */
  onFullScreenChange: (callback) => {
    const handler = (event, value) => callback(value)
    ipcRenderer.on('full-screen', handler)
    return () => ipcRenderer.removeListener('full-screen', handler)
  },

  /** 监听检查更新事件 */
  onCheckUpdate: (callback) => {
    const handler = (event, value) => callback(value)
    ipcRenderer.on('check-update', handler)
    return () => ipcRenderer.removeListener('check-update', handler)
  },

  /** 监听显示关于对话框 */
  onShowAbout: (callback) => {
    const handler = (event, value) => callback(value)
    ipcRenderer.on('show-about', handler)
    return () => ipcRenderer.removeListener('show-about', handler)
  },

  /** 监听新消息通知（用于未读数更新） */
  onNewMessage: (callback) => {
    const handler = (event, data) => callback(data)
    ipcRenderer.on('new-message', handler)
    return () => ipcRenderer.removeListener('new-message', handler)
  },

  // ============= 平台信息 =============
  /** 获取当前平台 */
  platform: process.platform,

  /** 是否为 macOS */
  isMac: process.platform === 'darwin',

  /** 是否为 Windows */
  isWindows: process.platform === 'win32',

  /** 是否为 Linux */
  isLinux: process.platform === 'linux',

  // ============= 应用控制 =============
  /** 退出应用程序（完全退出） */
  quitApp: () => ipcRenderer.invoke('quit-app'),

  /** 用户登出（只登出用户账号，不退出应用） */
  logoutUser: () => ipcRenderer.invoke('logout-user'),

  /** 重启应用程序 */
  relaunchApp: () => ipcRenderer.invoke('relaunch-app')
})

// 开发者工具信息
window.addEventListener('DOMContentLoaded', () => {
  // 替换版本信息占位符
  const replaceText = (selector, text) => {
    const element = document.getElementById(selector)
    if (element) element.textContent = text
  }

  for (const dependency of ['chrome', 'node', 'electron']) {
    replaceText(`${dependency}-version`, process.versions[dependency])
  }
})
