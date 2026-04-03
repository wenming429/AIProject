import { ref, computed, onMounted, onUnmounted } from 'vue'

/**
 * 桌面端环境检测与功能Hook
 * 用于检测是否在Electron环境中，并提供桌面端特有功能
 */

// 是否在桌面端
const isDesktop = ref(false)

// 平台信息
const platform = ref<string>('web')
const isWindows = ref(false)
const isMac = ref(false)
const isLinux = ref(false)

// 窗口状态
const isMaximized = ref(false)
const isFullscreen = ref(false)

// 初始化桌面端检测
export function useDesktop() {
  onMounted(() => {
    // 检测是否在Electron环境中
    if (window.$electron) {
      isDesktop.value = true
      platform.value = window.$electron.platform
      isWindows.value = window.$electron.isWindows
      isMac.value = window.$electron.isMac
      isLinux.value = window.$electron.isLinux
      
      // 初始化窗口状态
      checkWindowState()
    }
  })
  
  return {
    isDesktop: computed(() => isDesktop.value),
    platform: computed(() => platform.value),
    isWindows: computed(() => isWindows.value),
    isMac: computed(() => isMac.value),
    isLinux: computed(() => isLinux.value),
    isMaximized: computed(() => isMaximized.value),
    isFullscreen: computed(() => isFullscreen.value)
  }
}

/**
 * 窗口控制Hook
 */
export function useWindowControl() {
  // 最小化窗口
  const minimize = async () => {
    if (window.$electron) {
      await window.$electron.window.minimize()
    }
  }
  
  // 最大化/还原窗口
  const maximize = async () => {
    if (window.$electron) {
      await window.$electron.window.maximize()
      await checkWindowState()
    }
  }
  
  // 关闭窗口
  const close = async () => {
    if (window.$electron) {
      await window.$electron.window.close()
    }
  }
  
  // 设置全屏
  const setFullscreen = async (fullscreen: boolean) => {
    if (window.$electron) {
      await window.$electron.window.setFullScreen(fullscreen)
      isFullscreen.value = fullscreen
    }
  }
  
  // 检查窗口状态
  const checkWindowState = async () => {
    if (window.$electron) {
      isMaximized.value = await window.$electron.window.isMaximized()
      isFullscreen.value = await window.$electron.window.isFullScreen()
    }
  }
  
  return {
    minimize,
    maximize,
    close,
    setFullscreen,
    checkWindowState
  }
}

/**
 * 通知管理Hook
 */
export function useDesktopNotification() {
  // 设置任务栏徽章
  const setBadge = async (count: number) => {
    if (window.$electron) {
      await window.$electron.notification.setBadge(count)
    }
  }
  
  // 显示系统通知
  const showNotification = async (title: string, body: string, options?: { icon?: string; silent?: boolean }) => {
    if (window.$electron) {
      await window.$electron.notification.show({
        title,
        body,
        ...options
      })
    } else if ('Notification' in window) {
      // Web端回退到Web Notification API
      if (Notification.permission === 'granted') {
        new Notification(title, {
          body,
          icon: options?.icon || '/logo.svg'
        })
      }
    }
  }
  
  // 请求通知权限（Web端）
  const requestNotificationPermission = async () => {
    if (!window.$electron && 'Notification' in window) {
      const permission = await Notification.requestPermission()
      return permission === 'granted'
    }
    return true
  }
  
  return {
    setBadge,
    showNotification,
    requestNotificationPermission
  }
}

/**
 * 应用配置Hook
 */
export function useAppConfig() {
  // 获取配置
  const getConfig = async () => {
    if (window.$electron) {
      return await window.$electron.config.get()
    }
    // Web端使用localStorage
    const config = localStorage.getItem('lumenim_config')
    return config ? JSON.parse(config) : {}
  }
  
  // 设置配置项
  const setConfig = async (key: string, value: any) => {
    if (window.$electron) {
      await window.$electron.config.set(key, value)
    } else {
      // Web端使用localStorage
      const config = await getConfig()
      config[key] = value
      localStorage.setItem('lumenim_config', JSON.stringify(config))
    }
  }
  
  return {
    getConfig,
    setConfig
  }
}

/**
 * 系统功能Hook
 */
export function useSystem() {
  // 打开外部链接
  const openExternal = async (url: string) => {
    if (window.$electron) {
      await window.$electron.shell.openExternal(url)
    } else {
      window.open(url, '_blank')
    }
  }
  
  // 获取应用信息
  const getAppInfo = async () => {
    if (window.$electron) {
      return await window.$electron.app.getInfo()
    }
    return {
      platform: 'web',
      version: '1.0.0',
      appPath: '',
      userDataPath: '',
      downloadsPath: ''
    }
  }
  
  // 退出应用
  const quitApp = async () => {
    if (window.$electron) {
      await window.$electron.app.quit()
    }
  }
  
  // 重启应用
  const relaunchApp = async () => {
    if (window.$electron) {
      await window.$electron.app.relaunch()
    } else {
      window.location.reload()
    }
  }
  
  return {
    openExternal,
    getAppInfo,
    quitApp,
    relaunchApp
  }
}

// 默认导出
export default useDesktop
