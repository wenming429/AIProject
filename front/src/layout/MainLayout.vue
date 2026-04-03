<script lang="ts" setup>
import { isElectronMode } from '@/utils/electron.ts'
import Menu from './component/Menu.vue'
import Sponsor from './component/Sponsor.vue'
import { useThemeMode } from '@/hooks'

const { currentTheme } = useThemeMode()
</script>

<template>
  <section class="el-container is-vertical im-container" :style="{ backgroundColor: currentTheme.bgColor }">
    <main class="el-main">
      <section class="el-container">
        <aside 
          :class="{ 'pd-t20': isElectronMode() }" 
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

  .el-aside {
    width: 65px;
    box-sizing: border-box;
    transition: background-color 0.3s;
  }
}
</style>
