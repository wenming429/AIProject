import { defineStore } from 'pinia'
import { storage } from '@/utils'

// 预设名片背景主题色
export const presetCardThemes = [
  { name: '经典红', color: '#BF0008', gradient: 'linear-gradient(135deg, #BF0008 0%, #D41820 100%)' },
  { name: '商务蓝', color: '#1890ff', gradient: 'linear-gradient(135deg, #1890ff 0%, #36cfc9 100%)' },
  { name: '优雅紫', color: '#722ed1', gradient: 'linear-gradient(135deg, #722ed1 0%, #b37feb 100%)' },
  { name: '清新绿', color: '#52c41a', gradient: 'linear-gradient(135deg, #52c41a 0%, #95de64 100%)' },
  { name: '活力橙', color: '#fa8c16', gradient: 'linear-gradient(135deg, #fa8c16 0%, #ffc53d 100%)' },
  { name: '深邃青', color: '#13c2c2', gradient: 'linear-gradient(135deg, #13c2c2 0%, #5cdbd3 100%)' },
  { name: '浪漫粉', color: '#eb2f96', gradient: 'linear-gradient(135deg, #eb2f96 0%, #ffadd2 100%)' },
  { name: '沉稳灰', color: '#5B6B79', gradient: 'linear-gradient(135deg, #5B6B79 0%, #8B9BA9 100%)' },
]

export const useSettingsStore = defineStore('settings', {
  state: () => {
    return {
      isPromptTone: storage.get('isPromptTone', false), // 新消息提示音
      isKeyboard: storage.get('isKeyboard', false), // 是否推送键盘输入事件
      isLeaveWeb: false, // 是否离开网页
      isNotify: storage.get('isNotify', true), // 是否同意浏览器通知
      isFullScreen: storage.get('isFullScreen', true), // 是否客户端全屏
      themeMode: storage.get('themeMode', 'light-gray') as string,
      currentThemeMode: storage.get('themeMode', 'light-gray') as string,
      // 名片背景主题色设置
      cardThemeColor: storage.get('cardThemeColor', '') as string,
      cardThemeGradient: storage.get('cardThemeGradient', '') as string,
      useCustomCardTheme: storage.get('useCustomCardTheme', false) as boolean,
    }
  },
  actions: {
    setPromptTone(value: boolean) {
      this.isPromptTone = value
      storage.set('isPromptTone', value, null)
    },
    setKeyboard(value: boolean) {
      this.isKeyboard = value
      storage.set('isKeyboard', value, null)
    },
    setFullScreen(value: boolean) {
      this.isFullScreen = value
      storage.set('isFullScreen', value, null)
    },
    setThemeMode(value: string) {
      this.themeMode = value
      storage.set('themeMode', value, null)
    },
    setNotify(value: boolean) {
      this.isNotify = value
      storage.set('isNotify', value, null)
    },
    // 设置名片主题色
    setCardTheme(color: string, gradient: string) {
      this.cardThemeColor = color
      this.cardThemeGradient = gradient
      this.useCustomCardTheme = true
      storage.set('cardThemeColor', color, null)
      storage.set('cardThemeGradient', gradient, null)
      storage.set('useCustomCardTheme', true, null)
    },
    // 重置为默认主题色
    resetCardTheme() {
      this.cardThemeColor = ''
      this.cardThemeGradient = ''
      this.useCustomCardTheme = false
      storage.set('cardThemeColor', '', null)
      storage.set('cardThemeGradient', '', null)
      storage.set('useCustomCardTheme', false, null)
    },
    // 获取当前名片背景样式
    getCardBackground(defaultColor: string): string {
      if (this.useCustomCardTheme && this.cardThemeGradient) {
        return this.cardThemeGradient
      }
      return `linear-gradient(135deg, ${defaultColor} 0%, ${this.lightenColor(defaultColor, 20)} 100%)`
    }
  },
  getters: {
    // 获取当前名片主题色
    currentCardTheme(): string {
      return this.cardThemeColor || ''
    },
    //  lighten color helper
    lightenColor: () => (color: string, percent: number): string => {
      const num = parseInt(color.replace('#', ''), 16)
      const amt = Math.round(2.55 * percent)
      const R = (num >> 16) + amt
      const G = ((num >> 8) & 0x00ff) + amt
      const B = (num & 0x0000ff) + amt
      return '#' + (
        0x1000000 +
        (R < 255 ? (R < 1 ? 0 : R) : 255) * 0x10000 +
        (G < 255 ? (G < 1 ? 0 : G) : 255) * 0x100 +
        (B < 255 ? (B < 1 ? 0 : B) : 255)
      ).toString(16).slice(1)
    }
  }
})
