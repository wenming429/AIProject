/**
 * Electron API 类型声明
 * 桌面端扩展的 TypeScript 类型定义
 */

declare global {
  interface Window {
    /** Electron 桥接 API */
    $electron?: ElectronAPI
    /** 版本信息 */
    $versions?: VersionInfo
  }
}

/** Electron API 接口 */
export interface ElectronAPI {
  /** 平台信息 */
  platform: string
  isMac: boolean
  isWindows: boolean
  isLinux: boolean

  /** 窗口控制 */
  window: {
    minimize: () => Promise<void>
    maximize: () => Promise<void>
    close: () => Promise<void>
    hide: () => Promise<void>
    show: () => Promise<void>
    isMaximized: () => Promise<boolean>
    setFullScreen: (fullscreen: boolean) => Promise<void>
    isFullScreen: () => Promise<boolean>
  }

  /** 应用控制 */
  app: {
    getInfo: () => Promise<AppInfo>
    quit: () => Promise<void>
    relaunch: () => Promise<void>
    toggleDevTools: () => Promise<void>
  }

  /** 通知系统 */
  notification: {
    setBadge: (count: number) => Promise<void>
    show: (options: NotificationOptions) => Promise<void>
  }

  /** 外部链接 */
  shell: {
    openExternal: (url: string) => Promise<void>
  }

  /** 配置管理 */
  config: {
    get: () => Promise<AppConfig>
    set: (key: string, value: any) => Promise<void>
  }

  /** 缓存管理 */
  cache: {
    getPath: () => Promise<string>
    clear: () => Promise<{ success: boolean; error?: string }>
  }

  /** 下载管理 */
  download: {
    getPath: () => Promise<string>
    setPath: (path: string) => Promise<void>
  }

  /** 事件监听 */
  on: {
    maximizeChange: (callback: () => void) => () => void
    openSettings: (callback: () => void) => () => void
    newMessage: (callback: () => void) => () => void
  }
}

/** 应用信息 */
export interface AppInfo {
  platform: string
  version: string
  appPath: string
  userDataPath: string
  downloadsPath: string
}

/** 应用配置 */
export interface AppConfig {
  windowWidth?: number
  windowHeight?: number
  windowX?: number
  windowY?: number
  isMaximized?: boolean
  isFullScreen?: boolean
  theme?: 'light' | 'dark'
  language?: string
  notification?: {
    enabled: boolean
    sound: boolean
    badge: boolean
  }
  autoStart?: boolean
  minimizeToTray?: boolean
  closeToTray?: boolean
  downloadPath?: string
}

/** 通知选项 */
export interface NotificationOptions {
  title: string
  body: string
  icon?: string
  silent?: boolean
}

/** 版本信息 */
export interface VersionInfo {
  app: string
  electron: string
  chrome: string
  node: string
  v8: string
}

export {}
