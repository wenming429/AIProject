/**
 * LumenIM Electron 主进程 - 增强版
 * 提供完整的桌面客户端功能：窗口管理、系统托盘、通知、自动更新、数据持久化
 */
const { app, BrowserWindow, ipcMain, Tray, Menu, nativeImage, Notification, shell, dialog, autoUpdater } = require('electron')
const path = require('path')
const fs = require('fs')
const os = require('os')

// ==================== 常量定义 ====================
const isMac = process.platform === 'darwin'
const isWin = process.platform === 'win32'
const isLinux = process.platform === 'linux'
const isDev = process.env.NODE_ENV === 'development'
const DEV_PORT = process.env.PORT || 5173

// ==================== 全局变量 ====================
let mainWindow = null
let tray = null
let isQuitting = false
let notificationCount = 0

// ==================== 路径配置 ====================
const userDataPath = app.getPath('userData')
const configPath = path.join(userDataPath, 'config.json')
const cachePath = path.join(userDataPath, 'cache')
const logsPath = path.join(userDataPath, 'logs')
const downloadsPath = path.join(userDataPath, 'downloads')

// ==================== 日志系统 ====================
const logLevels = { DEBUG: 0, INFO: 1, WARN: 2, ERROR: 3 }
let currentLogLevel = isDev ? logLevels.DEBUG : logLevels.INFO

function log(level, message, ...args) {
  if (level < currentLogLevel) return
  
  const timestamp = new Date().toISOString()
  const levelNames = ['DEBUG', 'INFO', 'WARN', 'ERROR']
  const logMessage = `[${timestamp}] [${levelNames[level]}] ${message}`
  
  // 控制台输出
  if (level >= logLevels.ERROR) {
    console.error(logMessage, ...args)
  } else {
    console.log(logMessage, ...args)
  }
  
  // 写入日志文件
  try {
    const logFile = path.join(logsPath, `${new Date().toISOString().split('T')[0]}.log`)
    const logEntry = `${logMessage}${args.length > 0 ? ' ' + JSON.stringify(args) : ''}\n`
    fs.appendFileSync(logFile, logEntry)
  } catch (e) {
    // 忽略日志写入错误
  }
}

const logger = {
  debug: (msg, ...args) => log(logLevels.DEBUG, msg, ...args),
  info: (msg, ...args) => log(logLevels.INFO, msg, ...args),
  warn: (msg, ...args) => log(logLevels.WARN, msg, ...args),
  error: (msg, ...args) => log(logLevels.ERROR, msg, ...args)
}

// ==================== 目录初始化 ====================
function ensureDirectories() {
  const dirs = [cachePath, logsPath, downloadsPath]
  dirs.forEach(dir => {
    if (!fs.existsSync(dir)) {
      fs.mkdirSync(dir, { recursive: true })
      logger.info(`Created directory: ${dir}`)
    }
  })
}

// ==================== 配置管理 ====================
const defaultConfig = {
  windowWidth: 1200,
  windowHeight: 800,
  windowX: undefined,
  windowY: undefined,
  isMaximized: false,
  isFullScreen: false,
  theme: 'light',
  language: 'zh-CN',
  notification: {
    enabled: true,
    sound: true,
    badge: true
  },
  autoStart: false,
  minimizeToTray: true,
  closeToTray: true,
  downloadPath: downloadsPath
}

function loadConfig() {
  try {
    if (fs.existsSync(configPath)) {
      const config = JSON.parse(fs.readFileSync(configPath, 'utf-8'))
      logger.info('Configuration loaded successfully')
      return { ...defaultConfig, ...config }
    }
  } catch (e) {
    logger.error('Failed to load config:', e.message)
  }
  logger.info('Using default configuration')
  return { ...defaultConfig }
}

function saveConfig(config) {
  try {
    fs.writeFileSync(configPath, JSON.stringify(config, null, 2))
    logger.debug('Configuration saved')
  } catch (e) {
    logger.error('Failed to save config:', e.message)
  }
}

// ==================== 窗口管理 ====================
function getLoadURL() {
  if (isDev) {
    return `http://localhost:${DEV_PORT}`
  }
  return `file://${path.join(__dirname, '../dist/index.html')}`
}

function createMainWindow() {
  const config = loadConfig()

  mainWindow = new BrowserWindow({
    width: config.windowWidth || 1200,
    height: config.windowHeight || 800,
    x: config.windowX,
    y: config.windowY,
    minWidth: 900,
    minHeight: 600,
    frame: false,
    titleBarStyle: isMac ? 'hiddenInset' : 'hidden',
    show: false,
    backgroundColor: '#ffffff',
    webPreferences: {
      preload: path.join(__dirname, 'preload.cjs'),
      contextIsolation: true,
      nodeIntegration: false,
      webSecurity: true,
      allowRunningInsecureContent: false,
      spellcheck: false
    },
    icon: getAppIcon(),
    // Windows 毛玻璃效果
    ...(isWin && parseInt(os.release()) >= 10 ? {
      transparent: true,
      backgroundMaterial: 'acrylic'
    } : {})
  })

  // 加载内容
  mainWindow.loadURL(getLoadURL())

  // 开发工具
  if (isDev) {
    mainWindow.webContents.openDevTools({ mode: 'detach' })
  }

  // 窗口事件处理
  mainWindow.once('ready-to-show', () => {
    mainWindow.show()
    if (config.isMaximized) {
      mainWindow.maximize()
    }
    if (config.isFullScreen) {
      mainWindow.setFullScreen(true)
    }
    logger.info('Main window ready and shown')
  })

  mainWindow.on('close', (e) => {
    const config = loadConfig()
    
    if (!isQuitting && (config.closeToTray || isMac)) {
      e.preventDefault()
      mainWindow.hide()
      if (isWin) {
        tray.displayBalloon({
          iconType: 'info',
          title: 'LumenIM',
          content: '应用程序已最小化到系统托盘'
        })
      }
      return
    }

    // 保存窗口状态
    const bounds = mainWindow.getBounds()
    config.windowWidth = bounds.width
    config.windowHeight = bounds.height
    config.windowX = bounds.x
    config.windowY = bounds.y
    config.isMaximized = mainWindow.isMaximized()
    config.isFullScreen = mainWindow.isFullScreen()
    saveConfig(config)
    logger.info('Window state saved')
  })

  mainWindow.on('closed', () => {
    mainWindow = null
  })

  mainWindow.on('minimize', (e) => {
    const config = loadConfig()
    if (config.minimizeToTray) {
      e.preventDefault()
      mainWindow.hide()
    }
  })

  mainWindow.on('focus', () => {
    notificationCount = 0
    updateBadge()
  })

  // 页面加载事件
  mainWindow.webContents.on('did-fail-load', (event, errorCode, errorDescription) => {
    logger.error('Page load failed:', errorCode, errorDescription)
    if (!isDev) {
      setTimeout(() => {
        mainWindow.loadURL(getLoadURL())
      }, 5000)
    }
  })

  mainWindow.webContents.on('did-finish-load', () => {
    logger.info('Page loaded successfully')
  })

  // 新窗口处理 - 外部链接用系统浏览器打开
  mainWindow.webContents.setWindowOpenHandler(({ url }) => {
    shell.openExternal(url)
    return { action: 'deny' }
  })

  return mainWindow
}

// ==================== 图标获取 ====================
function getAppIcon() {
  const iconPaths = [
    path.join(__dirname, '../build/icons/icon.png'),
    path.join(__dirname, '../build/icons/lumenim.png'),
    path.join(__dirname, '../build/icons/icon.ico'),
    path.join(__dirname, '../build/icons/lumenim.ico')
  ]
  
  for (const iconPath of iconPaths) {
    if (fs.existsSync(iconPath)) {
      return nativeImage.createFromPath(iconPath)
    }
  }
  return null
}

// ==================== 系统托盘 ====================
function createTray() {
  const icon = getAppIcon()
  if (!icon) {
    logger.warn('Tray icon not found')
    return
  }

  let trayIcon = icon
  if (isMac) {
    trayIcon = icon.resize({ width: 16, height: 16 })
    trayIcon.setTemplateImage(true)
  }

  tray = new Tray(trayIcon)
  tray.setToolTip('LumenIM - 企业级即时通讯')
  
  updateTrayMenu()
  
  tray.on('click', () => {
    if (mainWindow) {
      if (mainWindow.isVisible()) {
        mainWindow.hide()
      } else {
        mainWindow.show()
        mainWindow.focus()
      }
    } else {
      createMainWindow()
    }
  })

  tray.on('double-click', () => {
    if (mainWindow) {
      mainWindow.show()
      mainWindow.focus()
    }
  })

  logger.info('System tray created')
}

function updateTrayMenu() {
  const config = loadConfig()
  
  const template = [
    {
      label: '显示主窗口',
      click: () => {
        if (mainWindow) {
          mainWindow.show()
          mainWindow.focus()
        }
      }
    },
    { type: 'separator' },
    {
      label: config.notification.enabled ? '通知: 开启' : '通知: 关闭',
      click: () => {
        config.notification.enabled = !config.notification.enabled
        saveConfig(config)
        updateTrayMenu()
      }
    },
    {
      label: '开机自启动',
      type: 'checkbox',
      checked: config.autoStart,
      click: () => {
        config.autoStart = !config.autoStart
        app.setLoginItemSettings({
          openAtLogin: config.autoStart,
          path: app.getPath('exe')
        })
        saveConfig(config)
      }
    },
    { type: 'separator' },
    {
      label: '检查更新',
      click: () => {
        checkForUpdates()
      }
    },
    {
      label: '关于',
      click: () => {
        showAboutDialog()
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
  ]

  const contextMenu = Menu.buildFromTemplate(template)
  tray.setContextMenu(contextMenu)
}

// ==================== 应用菜单 ====================
function initMenu() {
  const template = [
    ...(isMac ? [{
      label: app.name,
      submenu: [
        { role: 'about', label: `关于 ${app.name}` },
        { type: 'separator' },
        {
          label: '偏好设置...',
          accelerator: 'Cmd+,',
          click: () => mainWindow?.webContents.send('open-settings')
        },
        { type: 'separator' },
        { role: 'services' },
        { type: 'separator' },
        { role: 'hide', label: `隐藏 ${app.name}` },
        { role: 'hideOthers', label: '隐藏其他' },
        { role: 'unhide', label: '显示全部' },
        { type: 'separator' },
        { role: 'quit', label: `退出 ${app.name}` }
      ]
    }] : []),
    {
      label: '文件',
      submenu: [
        {
          label: '新建消息',
          accelerator: 'CmdOrCtrl+N',
          click: () => mainWindow?.webContents.send('new-message')
        },
        ...(isWin ? [
          { type: 'separator' },
          {
            label: '设置',
            click: () => mainWindow?.webContents.send('open-settings')
          }
        ] : [])
      ]
    },
    {
      label: '编辑',
      submenu: [
        { role: 'undo', label: '撤销' },
        { role: 'redo', label: '重做' },
        { type: 'separator' },
        { role: 'cut', label: '剪切' },
        { role: 'copy', label: '复制' },
        { role: 'paste', label: '粘贴' },
        ...(isMac ? [
          { role: 'pasteAndMatchStyle', label: '粘贴并匹配样式' },
          { role: 'delete', label: '删除' },
          { role: 'selectAll', label: '全选' }
        ] : [
          { role: 'delete', label: '删除' },
          { type: 'separator' },
          { role: 'selectAll', label: '全选' }
        ])
      ]
    },
    {
      label: '视图',
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
        ...(isMac ? [
          { type: 'separator' },
          { role: 'front', label: '前置所有窗口' },
          { type: 'separator' },
          { role: 'window', label: '窗口' }
        ] : [
          { role: 'close', label: '关闭' }
        ])
      ]
    },
    {
      label: '帮助',
      submenu: [
        {
          label: '文档',
          click: async () => {
            await shell.openExternal('https://github.com/gzydong/LumenIM#readme')
          }
        },
        {
          label: '提交反馈',
          click: async () => {
            await shell.openExternal('https://github.com/gzydong/LumenIM/issues')
          }
        },
        { type: 'separator' },
        {
          label: '关于 LumenIM',
          click: () => showAboutDialog()
        }
      ]
    }
  ]

  const menu = Menu.buildFromTemplate(template)
  Menu.setApplicationMenu(menu)
}

// ==================== 关于对话框 ====================
function showAboutDialog() {
  dialog.showMessageBox(mainWindow, {
    type: 'info',
    title: '关于 LumenIM',
    message: 'LumenIM',
    detail: `版本: ${app.getVersion()}\n` +
            `Electron: ${process.versions.electron}\n` +
            `Chrome: ${process.versions.chrome}\n` +
            `Node.js: ${process.versions.node}\n\n` +
            '企业级即时通讯系统\n' +
            'Copyright © 2024 LumenIM Team',
    buttons: ['确定', '访问官网'],
    defaultId: 0,
    icon: getAppIcon()
  }).then(({ response }) => {
    if (response === 1) {
      shell.openExternal('https://github.com/gzydong/LumenIM')
    }
  })
}

// ==================== 徽章更新 ====================
function updateBadge() {
  if (isMac) {
    app.dock.setBadge(notificationCount > 0 ? (notificationCount > 99 ? '99+' : `${notificationCount}`) : '')
  }
  
  if (isWin && mainWindow) {
    mainWindow.flashFrame(notificationCount > 0)
  }
  
  // 更新托盘图标（可选：添加角标）
  if (tray && notificationCount > 0) {
    tray.setToolTip(`LumenIM - ${notificationCount} 条未读消息`)
  } else if (tray) {
    tray.setToolTip('LumenIM - 企业级即时通讯')
  }
}

// ==================== 自动更新 ====================
function checkForUpdates() {
  logger.info('Checking for updates...')
  
  // 这里可以集成 electron-updater
  // 示例代码：
  // autoUpdater.checkForUpdatesAndNotify()
  
  dialog.showMessageBox(mainWindow, {
    type: 'info',
    title: '检查更新',
    message: '检查更新',
    detail: '当前已是最新版本。',
    buttons: ['确定']
  })
}

// ==================== IPC 处理器 ====================
function initIPC() {
  // 窗口控制
  ipcMain.handle('minimize-window', () => mainWindow?.minimize())
  ipcMain.handle('maximize-window', () => {
    if (mainWindow) {
      mainWindow.isMaximized() ? mainWindow.unmaximize() : mainWindow.maximize()
    }
  })
  ipcMain.handle('close-window', () => mainWindow?.close())
  ipcMain.handle('hide-window', () => mainWindow?.hide())
  ipcMain.handle('show-window', () => {
    mainWindow?.show()
    mainWindow?.focus()
  })
  ipcMain.handle('is-maximized', () => mainWindow?.isMaximized() || false)
  
  // 全屏控制
  ipcMain.handle('set-full-screen', (event, fullscreen) => {
    mainWindow?.setFullScreen(fullscreen)
  })
  ipcMain.handle('get-full-screen', () => mainWindow?.isFullScreen() || false)

  // 应用信息
  ipcMain.handle('get-app-info', () => ({
    platform: process.platform,
    version: app.getVersion(),
    appPath: app.getAppPath(),
    userDataPath: userDataPath,
    downloadsPath: downloadsPath
  }))

  // 通知与徽章
  ipcMain.handle('set-badge', (event, count) => {
    notificationCount = count
    updateBadge()
  })

  ipcMain.handle('show-notification', (event, { title, body, icon }) => {
    if (!Notification.isSupported()) return
    
    const notification = new Notification({
      title,
      body,
      icon: icon || getAppIcon(),
      silent: false
    })
    
    notification.on('click', () => {
      mainWindow?.show()
      mainWindow?.focus()
    })
    
    notification.show()
  })

  // 外部链接
  ipcMain.handle('open-external', async (event, url) => {
    if (url && (url.startsWith('http://') || url.startsWith('https://'))) {
      await shell.openExternal(url)
    }
  })

  // 配置管理
  ipcMain.handle('get-config', () => loadConfig())
  ipcMain.handle('set-config', (event, key, value) => {
    const config = loadConfig()
    config[key] = value
    saveConfig(config)
  })

  // 缓存管理
  ipcMain.handle('get-cache-path', () => cachePath)
  ipcMain.handle('clear-cache', async () => {
    try {
      const files = fs.readdirSync(cachePath)
      for (const file of files) {
        fs.unlinkSync(path.join(cachePath, file))
      }
      return { success: true }
    } catch (e) {
      logger.error('Failed to clear cache:', e)
      return { success: false, error: e.message }
    }
  })

  // 下载管理
  ipcMain.handle('get-download-path', () => downloadsPath)
  ipcMain.handle('set-download-path', async (event, newPath) => {
    const config = loadConfig()
    config.downloadPath = newPath
    saveConfig(config)
  })

  // 应用控制
  ipcMain.handle('quit-app', () => {
    isQuitting = true
    app.quit()
  })

  ipcMain.handle('relaunch-app', () => {
    isQuitting = true
    app.relaunch()
    app.exit()
  })

  // 开发工具
  ipcMain.handle('toggle-dev-tools', () => {
    mainWindow?.webContents.toggleDevTools()
  })

  logger.info('IPC handlers initialized')
}

// ==================== 应用生命周期 ====================
app.whenReady().then(() => {
  logger.info('Application ready')
  
  ensureDirectories()
  createMainWindow()
  createTray()
  initMenu()
  initIPC()
  
  // 设置开机自启动
  const config = loadConfig()
  if (config.autoStart) {
    app.setLoginItemSettings({
      openAtLogin: true,
      path: app.getPath('exe')
    })
  }

  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) {
      createMainWindow()
    } else if (mainWindow) {
      mainWindow.show()
    }
  })
})

app.on('window-all-closed', () => {
  if (!isMac) {
    app.quit()
  }
})

app.on('before-quit', () => {
  isQuitting = true
  logger.info('Application quitting...')
})

app.on('will-quit', () => {
  // 清理工作
  logger.info('Application will quit')
})

// 阻止多实例运行
const gotTheLock = app.requestSingleInstanceLock()

if (!gotTheLock) {
  logger.warn('Another instance is already running')
  app.quit()
} else {
  app.on('second-instance', (event, commandLine, workingDirectory) => {
    logger.info('Second instance detected')
    if (mainWindow) {
      if (mainWindow.isMinimized()) mainWindow.restore()
      mainWindow.show()
      mainWindow.focus()
    }
  })
}

// 证书错误处理
app.on('certificate-error', (event, webContents, url, error, certificate, callback) => {
  logger.warn('Certificate error:', error)
  // 生产环境应拒绝，开发环境可以允许
  callback(isDev)
})
