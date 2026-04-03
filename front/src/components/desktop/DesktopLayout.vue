<script setup lang="ts">
/**
 * 桌面端布局组件
 * 集成窗口控制、菜单栏和主内容区
 */
import { ref, computed, onMounted } from 'vue'
import WindowControls from './WindowControls.vue'
import { useThemeMode } from '@/hooks'

const { currentTheme } = useThemeMode()

// 检查是否为桌面端
const isDesktop = computed(() => !!window.$electron)

// 是否为Windows平台
const isWindows = computed(() => window.$electron?.isWindows || false)

// 窗口拖拽区域
const titleBarStyle = computed(() => ({
  backgroundColor: currentTheme.value.navBg,
  color: currentTheme.value.navText
}))
</script>

<template>
  <div 
    class="desktop-layout"
    :class="{ 'is-windows': isWindows }"
  >
    <!-- 自定义标题栏 (Windows) -->
    <div 
      v-if="isDesktop && isWindows" 
      class="title-bar"
      :style="titleBarStyle"
    >
      <div class="title-bar-content">
        <!-- 应用图标和名称 -->
        <div class="app-info">
          <img src="/logo.svg" alt="LumenIM" class="app-icon" />
          <span class="app-name">LumenIM</span>
        </div>
        
        <!-- 拖拽区域 -->
        <div class="drag-region"></div>
        
        <!-- 窗口控制按钮 -->
        <WindowControls />
      </div>
    </div>
    
    <!-- 主内容区域 -->
    <div class="main-content">
      <slot />
    </div>
  </div>
</template>

<style lang="less" scoped>
.desktop-layout {
  display: flex;
  flex-direction: column;
  height: 100vh;
  overflow: hidden;
  
  // Windows 平台需要预留标题栏空间
  &.is-windows {
    .main-content {
      height: calc(100vh - 32px);
    }
  }
  
  .title-bar {
    height: 32px;
    flex-shrink: 0;
    -webkit-app-region: drag;
    user-select: none;
    
    .title-bar-content {
      display: flex;
      align-items: center;
      height: 100%;
      padding: 0 0 0 12px;
      
      .app-info {
        display: flex;
        align-items: center;
        gap: 8px;
        -webkit-app-region: no-drag;
        
        .app-icon {
          width: 18px;
          height: 18px;
        }
        
        .app-name {
          font-size: 12px;
          font-weight: 500;
          opacity: 0.9;
        }
      }
      
      .drag-region {
        flex: 1;
        height: 100%;
      }
    }
  }
  
  .main-content {
    flex: 1;
    overflow: hidden;
    position: relative;
  }
}
</style>
