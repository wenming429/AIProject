<script setup lang="ts">
/**
 * 桌面端窗口控制组件
 * 提供最小化、最大化、关闭按钮
 */
import { ref, onMounted, onUnmounted, h } from 'vue'
import { Minus, Close } from '@icon-park/vue-next'

const isMaximized = ref(false)
const isFullscreen = ref(false)

// 自定义最大化图标（带边框的方框）
const MaximizeIcon = () => h('svg', {
  viewBox: '0 0 12 12',
  width: '12',
  height: '12',
  fill: 'none',
  stroke: 'currentColor',
  'stroke-width': '1',
}, [
  h('rect', { x: '1.5', y: '1.5', width: '9', height: '9', rx: '1' })
])

// 自定义还原图标（多个方框表示已最大化状态）
const RestoreIcon = () => h('svg', {
  viewBox: '0 0 12 12',
  width: '12',
  height: '12',
  fill: 'none',
  stroke: 'currentColor',
  'stroke-width': '1',
}, [
  h('rect', { x: '3.5', y: '0.5', width: '7', height: '7', rx: '1' }),
  h('path', { d: 'M0.5 3.5v7a1 1 0 001 1h7', 'stroke-width': '1' })
])

// 检查窗口状态
async function checkWindowState() {
  if (window.$electron) {
    try {
      isMaximized.value = await window.$electron.isMaximized?.()
      isFullscreen.value = await window.$electron.getFullScreenStatus?.()
    } catch (e) {
      console.error('[WindowControls] Failed to get window state:', e)
    }
  }
}

// 最小化
function minimize() {
  if (window.$electron?.minimizeWindow) {
    window.$electron.minimizeWindow()
  } else {
    console.warn('[WindowControls] minimizeWindow not available')
  }
}

// 最大化/还原
async function maximize() {
  if (window.$electron?.maximizeWindow) {
    await window.$electron.maximizeWindow()
    checkWindowState()
  } else {
    console.warn('[WindowControls] maximizeWindow not available')
  }
}

// 关闭
function close() {
  if (window.$electron?.closeWindow) {
    window.$electron.closeWindow()
  } else {
    console.warn('[WindowControls] closeWindow not available')
  }
}

// 监听窗口状态变化
let unsubscribeFullscreen: (() => void) | null = null

onMounted(() => {
  checkWindowState()
  
  // 订阅全屏状态变化
  if (window.$electron?.onFullScreenChange) {
    unsubscribeFullscreen = window.$electron.onFullScreenChange((value: boolean) => {
      isFullscreen.value = value
    })
  }
})

onUnmounted(() => {
  unsubscribeFullscreen?.()
})
</script>

<template>
  <div class="window-controls">
    <button class="control-btn minimize" @click="minimize" title="最小化">
      <n-icon :component="Minus" :size="12" />
    </button>
    <button class="control-btn maximize" @click="maximize" :title="isMaximized ? '还原' : '最大化'">
      <n-icon :component="isMaximized ? RestoreIcon : MaximizeIcon" :size="12" />
    </button>
    <button class="control-btn close" @click="close" title="关闭">
      <n-icon :component="Close" :size="12" />
    </button>
  </div>
</template>

<style lang="less" scoped>
.window-controls {
  display: flex;
  align-items: center;
  gap: 0;
  -webkit-app-region: no-drag;
  
  .control-btn {
    width: 46px;
    height: 32px;
    display: flex;
    align-items: center;
    justify-content: center;
    border: none;
    background: transparent;
    color: var(--im-text-color);
    cursor: pointer;
    transition: all 0.15s ease;
    
    &:hover {
      background: rgba(0, 0, 0, 0.08);
    }
    
    &.minimize:hover {
      background: rgba(0, 0, 0, 0.06);
    }
    
    &.maximize:hover {
      background: rgba(0, 0, 0, 0.06);
    }
    
    &.close:hover {
      background: #e81123;
      color: white;
    }
    
    &:active {
      transform: scale(0.95);
    }
  }
}

// 平台检测类（通过 JS 动态添加）
:global(.platform-darwin) .window-controls {
  display: none;
}
</style>
