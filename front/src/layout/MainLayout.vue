<script lang="ts" setup>
import { isElectronMode } from '@/utils/electron.ts'
import Menu from './component/Menu.vue'
import Sponsor from './component/Sponsor.vue'
import WindowControls from '@/components/desktop/WindowControls.vue'
import { useThemeMode } from '@/hooks'
import { computed, onMounted } from 'vue'

const { currentTheme } = useThemeMode()

// 检测是否为 Windows 平台
const isWindows = computed(() => {
  return typeof window !== 'undefined' && 
         navigator.userAgent.includes('Windows') && 
         isElectronMode()
})

// 在 macOS 上不显示自定义窗口控制按钮
const showWindowControls = computed(() => {
  if (!isElectronMode()) return false
  // 只在 Windows 上显示（macOS 使用原生窗口按钮）
  return isWindows.value
})

// 平台检测类
onMounted(() => {
  if (isElectronMode()) {
    const platform = navigator.platform.toLowerCase()
    if (platform.includes('darwin')) {
      document.body.classList.add('platform-darwin')
    } else if (platform.includes('win')) {
      document.body.classList.add('platform-win32')
    }
  }
})
</script>

<template>
  <section class="el-container is-vertical im-container" :style="{ backgroundColor: currentTheme.bgColor }">
    <!-- 窗口控制按钮 (Windows 专用) -->
    <header v-if="showWindowControls" class="window-header app-drag">
      <WindowControls />
    </header>

    <main class="el-main">
      <section class="el-container">
        <aside 
          :class="{ 'pd-t20': isElectronMode() && !showWindowControls }" 
          class="el-aside app-drag border-right"
          :style="{ backgroundColor: currentTheme.navBg }"
        >
          <Menu />
        </aside>
        <main class="el-main" :style="{ backgroundColor: currentTheme.bgColor }">
          <router-view />
        </main>
      </section>
    </main>
  </section>

  <Sponsor />
</template>

<style lang="less" scoped>
.im-container {
  height: 100vh;
  width: 100vw;
  overflow: hidden;
  transition: background-color 0.3s;

  .window-header {
    height: 32px;
    background: v-bind('currentTheme.navBg');
    display: flex;
    justify-content: flex-end;
    align-items: center;
    flex-shrink: 0;
    transition: background-color 0.3s;
  }

  .el-aside {
    width: 65px;
    box-sizing: border-box;
    transition: background-color 0.3s;
  }
}
</style>
