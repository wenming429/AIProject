<script setup lang="ts">
/**
 * 桌面端推广组件
 * 在Web端提示用户可以下载桌面客户端
 */
import { ref, onMounted } from 'vue'
import { Computer, Close } from '@icon-park/vue-next'
import { useMessage } from 'naive-ui'

const message = useMessage()
const showPromo = ref(false)

// 检查是否在浏览器中运行
const isBrowser = ref(false)

onMounted(() => {
  // 如果不在Electron环境中，显示推广
  isBrowser.value = !window.$electron
  
  // 检查本地存储，看用户是否已关闭提示
  const dismissed = localStorage.getItem('desktop_promo_dismissed')
  const dismissDate = dismissed ? parseInt(dismissed) : 0
  const oneWeek = 7 * 24 * 60 * 60 * 1000
  
  if (isBrowser.value && (!dismissed || Date.now() - dismissDate > oneWeek)) {
    showPromo.value = true
  }
})

// 关闭提示
function dismiss() {
  showPromo.value = false
  localStorage.setItem('desktop_promo_dismissed', Date.now().toString())
}

// 下载桌面端
function downloadDesktop() {
  // 根据平台提供下载链接
  const platform = navigator.platform.toLowerCase()
  let downloadUrl = 'https://github.com/gzydong/LumenIM/releases'
  
  if (platform.includes('win')) {
    downloadUrl += '/download/latest/LumenIM-1.0.0-x64.exe'
  } else if (platform.includes('mac')) {
    downloadUrl += '/download/latest/LumenIM-1.0.0-x64.dmg'
  } else if (platform.includes('linux')) {
    downloadUrl += '/download/latest/LumenIM-1.0.0-x64.AppImage'
  }
  
  window.open(downloadUrl, '_blank')
  message.success('正在跳转到下载页面')
}

// 了解更多
function learnMore() {
  window.open('https://github.com/gzydong/LumenIM#readme', '_blank')
}
</script>

<template>
  <div v-if="showPromo" class="desktop-promo">
    <div class="promo-content">
      <div class="promo-icon">
        <n-icon :component="Computer" :size="24" />
      </div>
      <div class="promo-text">
        <div class="promo-title">获取更好的体验</div>
        <div class="promo-desc">下载桌面客户端，享受原生通知、系统托盘和更流畅的体验</div>
      </div>
      <div class="promo-actions">
        <n-button type="primary" size="small" @click="downloadDesktop">
          立即下载
        </n-button>
        <n-button text size="small" @click="learnMore">
          了解更多
        </n-button>
      </div>
      <button class="promo-close" @click="dismiss">
        <n-icon :component="Close" :size="14" />
      </button>
    </div>
  </div>
</template>

<style lang="less" scoped>
.desktop-promo {
  position: fixed;
  top: 60px;
  right: 20px;
  z-index: 1000;
  animation: slideIn 0.3s ease;
  
  @keyframes slideIn {
    from {
      opacity: 0;
      transform: translateX(20px);
    }
    to {
      opacity: 1;
      transform: translateX(0);
    }
  }
  
  .promo-content {
    display: flex;
    align-items: center;
    gap: 12px;
    padding: 16px 20px;
    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
    border-radius: 12px;
    box-shadow: 0 4px 20px rgba(102, 126, 234, 0.3);
    color: white;
    max-width: 400px;
    position: relative;
    
    .promo-icon {
      flex-shrink: 0;
      width: 44px;
      height: 44px;
      background: rgba(255, 255, 255, 0.2);
      border-radius: 10px;
      display: flex;
      align-items: center;
      justify-content: center;
    }
    
    .promo-text {
      flex: 1;
      
      .promo-title {
        font-size: 15px;
        font-weight: 600;
        margin-bottom: 4px;
      }
      
      .promo-desc {
        font-size: 12px;
        opacity: 0.9;
        line-height: 1.4;
      }
    }
    
    .promo-actions {
      display: flex;
      flex-direction: column;
      gap: 6px;
      
      :deep(.n-button) {
        color: white;
        
        &.n-button--primary-type {
          background: rgba(255, 255, 255, 0.9);
          color: #667eea;
          
          &:hover {
            background: white;
          }
        }
      }
    }
    
    .promo-close {
      position: absolute;
      top: 8px;
      right: 8px;
      width: 20px;
      height: 20px;
      display: flex;
      align-items: center;
      justify-content: center;
      background: rgba(255, 255, 255, 0.2);
      border: none;
      border-radius: 4px;
      color: white;
      cursor: pointer;
      opacity: 0.7;
      transition: all 0.2s;
      
      &:hover {
        opacity: 1;
        background: rgba(255, 255, 255, 0.3);
      }
    }
  }
}

// 响应式
@media (max-width: 768px) {
  .desktop-promo {
    left: 10px;
    right: 10px;
    top: auto;
    bottom: 20px;
    
    .promo-content {
      max-width: none;
    }
  }
}
</style>
