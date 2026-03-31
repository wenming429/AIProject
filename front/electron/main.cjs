/**
 * LumenIM Electron 主进程
 * 负责窗口管理、系统托盘、通知、本地存储等桌面原生功能
 */
const { app, BrowserWindow, ipcMain, Tray, Menu, nativeImage, Notification, shell } = require('electron')
const path = require('path')
const fs = require('fs')

const isMac = process.platform === 'darwin'
const isDev = process.env.NODE_ENV === 'development'

// 开发环境端口
const DEV_PORT = process.env.PORT || 5173

// 全局变量
let mainWindow = null
let tray = null
let isQuitting = false

// 用户数据路径
const userDataPath = app.getPath('userData')
const configPath = path.join(userDataPath, 'config.json')
const cachePath = path.join(userDataPath, 'cache')

// 确保目录存在
function ensureDirectories() {
  if (!fs.existsSync(cachePath)) {
    fs.mkdirSync(cachePath, { recursive: true })
  }
}

// 加载本地配置
function loadConfig() {
  try {
    if (fs.existsSync(configPath)) {
      return JSON.parse(fs.readFileSync(configPath, 'utf-8'))
    }
  } catch (e) {
    console.error('Failed to load config:', e)
  }
  return {}
}

// 保存本地配置
function saveConfig(config) {
  try {
    fs.writeFileSync(configPath, JSON.stringify(config, null, 2))
  } catch (e) {
    console.error('Failed to save config:', e)
  }
}

// 构建加载 URL
function getLoadURL() {
  if (isDev) {
    return `http://localhost:${DEV_PORT}`
  }
  return `file://${path.join(__dirname, '../dist/index.html')}`
}

// 创建主窗口
function createMainWindow() {
  const config = loadConfig()

  mainWindow = new BrowserWindow({
    width: config.windowWidth || 1200,
    height: config.windowHeight || 800,
    x: config.windowX,
    y: config.windowY,
    minWidth: 900,
    minHeight: 600,
    frame: false,           // 无边框窗口
    titleBarStyle: 'hidden', // macOS 隐藏标题栏
    show: false,            // 先隐藏，准备好再显示
    webPreferences: {
      preload: path.join(__dirname, 'preload.cjs'),
      contextIsolation: true,
      nodeIntegration: false,
      webSecurity: true,
      allowRunningInsecureContent: false
    },
    icon: path.join(__dirname, '../build/icons/icon.png')
  })

  // 加载内容
  mainWindow.loadURL(getLoadURL())

  // 开发环境打开 DevTools
  if (isDev) {
    mainWindow.webContents.openDevTools({ mode: 'detach' })
  }

  // 窗口准备好后显示
  mainWindow.once('ready-to-show', () => {
    mainWindow.show()
    // 恢复最大化状态
    if (config.isMaximized) {
      mainWindow.maximize()
    }
  })

  // 窗口关闭事件
  mainWindow.on('close', (e) => {
    if (!isQuitting && isMac) {
      // macOS 点击关闭按钮时隐藏到托盘
      e.preventDefault()
      mainWindow.hide()
      return
    }

    // 保存窗口状态
    const bounds = mainWindow.getBounds()
    const config = loadConfig()
    config.windowWidth = bounds.width
    config.windowHeight = bounds.height
    config.windowX = bounds.x
    config.windowY = bounds.y
    config.isMaximized = mainWindow.isMaximized()
    saveConfig(config)
  })

  // 窗口销毁
  mainWindow.on('closed', () => {
    mainWindow = null
  })

  // 页面加载错误
  mainWindow.webContents.on('did-fail-load', (event, errorCode, errorDescription) => {
    console.error('Failed to load:', errorCode, errorDescription)
  })

  // 页面加载完成
  mainWindow.webContents.on('did-finish-load', () => {
    console.log('Page loaded successfully')
  })
}

// 创建系统托盘
function createTray() {
  // 托盘图标 - Windows 使用 .ico，macOS 使用 .png
  const iconPath = isMac
    ? path.join(__dirname, '../build/icons/lumenim.png')
    : path.join(__dirname, '../build/icons/lumenim.ico')
  let trayIcon

  if (fs.existsSync(iconPath)) {
    trayIcon = nativeImage.createFromPath(iconPath)
    // macOS 需要模板图片
    if (isMac) {
      trayIcon = trayIcon.resize({ width: 16, height: 16 })
    }
  } else {
    // 创建默认图标
    trayIcon = nativeImage.createEmpty()
  }

  tray = new Tray(trayIcon)

  const contextMenu = Menu.buildFromTemplate([
    {
      label: '显示 LumenIM',
      click: () => {
        if (mainWindow) {
          mainWindow.show()
          mainWindow.focus()
        }
      }
    },
    { type: 'separator' },
    {
      label: '检查更新',
      click: () => {
        if (mainWindow) {
          mainWindow.webContents.send('check-update')
        }
      }
    },
    { type: 'separator' },
    {
      label: '退出',
      click: () => {
        isQuitting = true
        app.quit()
      }
    }
  ])

  tray.setToolTip('LumenIM')
  tray.setContextMenu(contextMenu)

  // 点击托盘图标
  tray.on('click', () => {
    if (mainWindow) {
      if (mainWindow.isVisible()) {
        mainWindow.hide()
      } else {
        mainWindow.show()
        mainWindow.focus()
      }
    }
  })

  // 双击显示窗口
  tray.on('double-click', () => {
    if (mainWindow) {
      mainWindow.show()
      mainWindow.focus()
    }
  })
}

// 初始化菜单
function initMenu() {
  const template = [
    ...(isMac
      ? [{
          label: app.name,
          submenu: [
            { role: 'about', label: `关于 ${app.name}` },
            {
              label: '检查更新',
              click: () => mainWindow?.webContents.send('check-update')
            },
            { type: 'separator' },
            { role: 'services' },
            { role: 'hide', label: `隐藏 ${app.name}` },
            { role: 'hideOthers', label: '隐藏其它应用' },
            { role: 'unhide', label: '显示所有应用' },
            { type: 'separator' },
            { role: 'quit', label: `退出 ${app.name}` }
          ]
        }]
      : []),
    {
      label: '编辑',
      submenu: [
        { role: 'undo', label: '撤销' },
        { role: 'redo', label: '重做' },
        { type: 'separator' },
        { role: 'cut', label: '剪切' },
        { role: 'copy', label: '复制' },
        { role: 'paste', label: '粘贴' },
        ...(isMac
          ? [
              { role: 'pasteAndMatchStyle', label: '粘贴并匹配样式' },
              { role: 'delete', label: '删除' },
              { role: 'selectAll', label: '全选' }
            ]
          : [
              { role: 'delete', label: '删除' },
              { type: 'separator' },
              { role: 'selectAll', label: '全选' }
            ])
      ]
    },
    {
      label: '显示',
      submenu: [
        { role: 'reload', label: '刷新' },
        { role: 'forceReload', label: '强制刷新' },
        ...(isDev ? [{ role: 'toggleDevTools', label: '开发者工具' }] : []),
        { type: 'separator' },
        { role: 'resetZoom', label: '实际大小' },
        { role: 'zoomIn', label: '放大' },
        { role: 'zoomOut', label: '缩小' },
        { type: 'separator' },
        { role: 'togglefullscreen', label: '全屏' }
      ]
    },
    {
      label: '窗口',
      submenu: [
        { role: 'minimize', label: '最小化' },
        { role: 'zoom', label: '缩放' },
        ...(isMac
          ? [
              { type: 'separator' },
              { role: 'front', label: '前置所有窗口' },
              { type: 'separator' },
              { role: 'window', label: '窗口' }
            ]
          : [{ role: 'close', label: '关闭' }])
      ]
    },
    {
      label: '帮助',
      submenu: [
        {
          label: '关于 LumenIM',
          click: () => {
            if (mainWindow) {
              mainWindow.webContents.send('show-about')
            }
          }
        },
        {
          label: '访问官网',
          click: async () => {
            await shell.openExternal('https://github.com/gzydong/LumenIM')
          }
        }
      ]
    }
  ]

  const menu = Menu.buildFromTemplate(template)
  Menu.setApplicationMenu(menu)
}

// 应用准备就绪
app.whenReady().then(() => {
  ensureDirectories()
  createMainWindow()
  createTray()
  initMenu()

  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) {
      createMainWindow()
    } else if (mainWindow) {
      mainWindow.show()
      mainWindow.focus()
    }
  })
})

// 所有窗口关闭
app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') {
    app.quit()
  }
})

// 应用退出前
app.on('before-quit', () => {
  isQuitting = true
})

// ============= IPC 处理器 =============

// 获取全屏状态
ipcMain.handle('get-full-screen', () => {
  return mainWindow?.isFullScreen() || false
})

// 设置全屏
ipcMain.handle('set-full-screen', (event, fullscreen) => {
  if (mainWindow) {
    mainWindow.setFullScreen(fullscreen)
  }
})

// 获取窗口最小化状态
ipcMain.handle('get-minimized', () => {
  return mainWindow?.isMinimized() || false
})

// 最小化窗口
ipcMain.handle('minimize-window', () => {
  if (mainWindow) {
    mainWindow.minimize()
  }
})

// 最大化/还原窗口
ipcMain.handle('maximize-window', () => {
  if (mainWindow) {
    if (mainWindow.isMaximized()) {
      mainWindow.unmaximize()
    } else {
      mainWindow.maximize()
    }
  }
})

// 获取窗口最大化状态
ipcMain.handle('is-maximized', () => {
  return mainWindow?.isMaximized() || false
})

// 关闭窗口
ipcMain.handle('close-window', () => {
  if (mainWindow) {
    mainWindow.close()
  }
})

// 隐藏窗口
ipcMain.handle('hide-window', () => {
  if (mainWindow) {
    mainWindow.hide()
  }
})

// 显示窗口
ipcMain.handle('show-window', () => {
  if (mainWindow) {
    mainWindow.show()
    mainWindow.focus()
  }
})

// 获取应用信息
ipcMain.handle('get-app-info', () => {
  return {
    platform: process.platform,
    version: app.getVersion(),
    appPath: app.getAppPath(),
    userDataPath: userDataPath
  }
})

// 设置任务栏徽章（未读消息数）
ipcMain.handle('set-badge', (event, count) => {
  if (process.platform === 'darwin') {
    app.dock.setBadge(count > 0 ? (count > 99 ? '99+' : `${count}`) : '')
  }
  // Windows/Linux 可以使用任务栏闪烁
  if (process.platform === 'win32' && mainWindow) {
    if (count > 0) {
      mainWindow.flashFrame(true)
    } else {
      mainWindow.flashFrame(false)
    }
  }
})

// 打开外部链接
ipcMain.handle('open-external', async (event, url) => {
  // 安全检查：只允许 http/https 协议
  if (url && (url.startsWith('http://') || url.startsWith('https://'))) {
    await shell.openExternal(url)
  }
})

// 显示系统通知
ipcMain.handle('show-notification', (event, { title, body, silent }) => {
  if (Notification.isSupported()) {
    const notification = new Notification({
      title,
      body,
      silent: silent || false,
      icon: path.join(__dirname, '../build/icons/icon.png')
    })
    notification.on('click', () => {
      if (mainWindow) {
        mainWindow.show()
        mainWindow.focus()
      }
    })
    notification.show()
  }
})

// 读写本地配置
ipcMain.handle('get-config', () => {
  return loadConfig()
})

ipcMain.handle('set-config', (event, key, value) => {
  const config = loadConfig()
  config[key] = value
  saveConfig(config)
})

// 获取缓存路径
ipcMain.handle('get-cache-path', () => {
  return cachePath
})

// 清除缓存
ipcMain.handle('clear-cache', async () => {
  try {
    const files = fs.readdirSync(cachePath)
    for (const file of files) {
      fs.unlinkSync(path.join(cachePath, file))
    }
    return true
  } catch (e) {
    console.error('Failed to clear cache:', e)
    return false
  }
})

// 获取本地 IP 地址
ipcMain.handle('get-local-ip', () => {
  const os = require('os')
  const interfaces = os.networkInterfaces()
  for (const name of Object.keys(interfaces)) {
    for (const iface of interfaces[name]) {
      if (iface.family === 'IPv4' && !iface.internal) {
        return iface.address
      }
    }
  }
  return '127.0.0.1'
})

// ============= 应用退出 =============
// 退出应用程序
ipcMain.handle('quit-app', () => {
  isQuitting = true
  app.quit()
})

// 登录退出（只登出用户，不退出应用）
ipcMain.handle('logout-user', () => {
  // 这个接口只是给前端一个信号，前端会处理用户登出逻辑
  // 应用本身不退出
  console.log('User logout requested')
})

// 重启应用程序
ipcMain.handle('relaunch-app', () => {
  isQuitting = true
  app.relaunch()
  app.exit()
})
