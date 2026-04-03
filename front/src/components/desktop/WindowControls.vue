<script setup lang="ts">
/**
 * 桌面端窗口控制组件
 * 提供最小化、最大化、关闭按钮
 */
import { ref, onMounted, onUnmounted } from 'vue'
import { Minus, Square, FullscreenOne, Close } from '@icon-park/vue-next'

const isMaximized = ref(false)
const isFullscreen = ref(false)

// 检查窗口状态
async function checkWindowState() {
  if (window.$electron) {
    isMaximized.value = await window.$electron.window.isMaximized()
    isFullscreen.value = await window.$electron.window.isFullScreen()
  }
}

// 最小化
function minimize() {
  window.$electron?.window.minimize()
}

// 最大化/还原
async function maximize() {
  await window.$electron?.window.maximize()
  checkWindowState()
}

// 关闭
function close() {
  window.$electron?.window.close()
}

// 监听窗口状态变化
let unsubscribe: (() => void) | null = null

onMounted(() => {
  checkWindowState()
  
  // 订阅状态变化
  if (window.$electron?.on?.maximizeChange) {
    unsubscribe = window.$electron.on.maximizeChange(() => {
      checkWindowState()
    })
  }
})

onUnmounted(() => {
  unsubscribe?.()
})
</script>

<template>
  <div class="window-controls">
    <button class="control-btn minimize" @click="minimize" title="最小化">
      <n-icon :component="Minus" :size="12" />
    </button>
    <button class="control-btn maximize" @click="maximize" title="最大化/还原">
      <n-icon :component="isMaximized ? FullscreenOne : Square" :size="12" />
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
    width: 40px;
    height: 30px;
    display: flex;
    align-items: center;
    justify-content: center;
    border: none;
    background: transparent;
    color: var(--im-text-secondary);
    cursor: pointer;
    transition: all 0.2s ease;
    
    &:hover {
      background: var(--im-bg-hover);
    }
    
    &.minimize:hover {
      background: rgba(0, 0, 0, 0.05);
    }
    
    &.maximize:hover {
      background: rgba(0, 0, 0, 0.05);
    }
    
    &.close:hover {
      background: #ff4d4f;
      color: white;
    }
  }
}

// Windows 平台样式
:global(.platform-win32) .window-controls {
  .control-btn {
    width: 45px;
    height: 32px;
    
    &.close:hover {
      background: #e81123;
    }
  }
}

// macOS 平台隐藏（使用系统原生按钮）
:global(.platform-darwin) .window-controls {
  display: none;
}
</style>
