import { computed, onMounted, onUnmounted, ref, watchEffect } from 'vue'
import { useSettingsStore } from '@/store'
import { huaxiaRedNaiveOverrides, lightGrayNaiveOverrides, getThemeConfig } from '@/constant/theme'
import { darkTheme } from 'naive-ui'

const themeModeKey = 'theme-mode'

// 有效的主题键
const validThemes = ['huaxia-red', 'light-gray']

export function useThemeMode() {
  const settingsStore = useSettingsStore()
  
  // 当前主题模式
  const themeMode = computed(() => {
    const theme = settingsStore.themeMode
    // 兼容旧主题值
    if (theme === 'light') return 'huaxia-red'
    if (theme === 'dark') return 'huaxia-red'
    if (theme === 'auto') return 'huaxia-red'
    return validThemes.includes(theme) ? theme : 'huaxia-red'
  })

  // 应用主题到 DOM
  const applyThemeToDOM = (mode: string) => {
    document.documentElement.setAttribute(themeModeKey, mode)
  }

  // 获取 Naive UI 主题配置
  const getDarkTheme = computed(() => {
    // 新主题系统不使用 darkTheme
    return undefined
  })

  // 获取 Naive UI 主题覆盖
  const getThemeOverride = computed(() => {
    switch (themeMode.value) {
      case 'light-gray':
        return lightGrayNaiveOverrides
      case 'huaxia-red':
      default:
        return huaxiaRedNaiveOverrides
    }
  })

  // 获取当前主题配置
  const currentTheme = computed(() => {
    return getThemeConfig(themeMode.value)
  })

  // 监听主题变化
  watchEffect(() => {
    applyThemeToDOM(themeMode.value)
    settingsStore.currentThemeMode = themeMode.value
  })

  onMounted(() => {
    // 初始化时应用主题
    applyThemeToDOM(themeMode.value)
  })

  return { 
    getDarkTheme, 
    getThemeOverride,
    currentTheme,
    themeMode 
  }
}

// 切换主题函数
export function useThemeSwitcher() {
  const settingsStore = useSettingsStore()
  
  const switchTheme = (themeKey: string) => {
    if (validThemes.includes(themeKey)) {
      settingsStore.setThemeMode(themeKey)
    }
  }
  
  const themes = [
    { key: 'huaxia-red', name: '华夏红', color: '#BF0008' },
    { key: 'light-gray', name: '浅灰', color: '#5B6B79' },
  ]
  
  return {
    switchTheme,
    themes,
    validThemes
  }
}
