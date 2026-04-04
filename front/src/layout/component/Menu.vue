<script lang="ts" setup>
import { useSettingsStore, useTalkStore, useUserStore } from '@/store'
import { Message, NotebookOne, People, SettingTwo } from '@icon-park/vue-next'
import AccountCard from './AccountCard.vue'
import { NModal } from 'naive-ui'
import { useThemeMode } from '@/hooks'

const userStore = useUserStore()
const talkStore = useTalkStore()
const router = useRouter()
const settingsStore = useSettingsStore()
const { currentTheme } = useThemeMode()

// 根据主题获取图标颜色
const getIconColor = (isActive: boolean) => {
  if (isActive) {
    return currentTheme.value.primary
  }
  return currentTheme.value.navText
}

const menus = reactive([
  {
    link: '/message',
    icon: markRaw(Message),
    title: '消息',
    hotspot: computed(() => talkStore.talkUnreadNum > 0)
  },
  {
    link: '/contact',
    icon: markRaw(People),
    title: '通讯录',
    hotspot: computed(() => userStore.isContactApply || userStore.isGroupApply)
  },
  {
    link: '/note',
    icon: markRaw(NotebookOne),
    title: '笔记'
  },
  {
    link: '/settings',
    icon: markRaw(SettingTwo),
    title: '设置'
  }
])

// 退出菜单状态
const showLogoutMenu = ref(false)

// 显示退出菜单
const onShowLogoutMenu = () => {
  showLogoutMenu.value = true
}

// 登出（切换账号）
const onLogout = () => {
  showLogoutMenu.value = false
  userStore.logoutLogin()
}

// 退出应用
const onQuitApp = () => {
  showLogoutMenu.value = false
  // 调用 Electron 退出接口
  if ((window as any).$electron?.quitApp) {
    ;(window as any).$electron.quitApp()
  } else {
    // 非 Electron 环境，直接关闭窗口
    window.close()
  }
}

// 导航点击处理 - 增强版，带错误处理和调试
const onClickMenu = (menu: any, event?: Event) => {
  try {
    // 阻止事件冒泡，防止被其他元素拦截
    event?.stopPropagation()
    event?.preventDefault()

    if (menu.external) {
      window.open(menu.link)
      return
    }

    // 获取当前路径
    const currentPath = router.currentRoute.value.path
    // 目标路径
    const targetPath = menu.link

    // 如果点击的是当前页面，不进行导航
    if (currentPath === targetPath || currentPath.startsWith(targetPath + '/')) {
      return
    }

    // 执行导航
    router.push(targetPath)
  } catch (error) {
    console.error('[Menu] Navigation error:', error)
  }
}

// 判断菜单是否激活
const isActive = (menu: any) => {
  const path = router.currentRoute.value.path
  return path === menu.link || path.startsWith(menu.link + '/')
}
</script>

<template>
  <section class="menu" :style="{ backgroundColor: currentTheme.navBg }">
    <header class="menu-header" :url="router.currentRoute.value.path">
      <n-popover
        placement="right"
        trigger="click"
        :raw="true"
        style="margin-left: 16px; border-radius: 8px; overflow: hidden"
      >
        <template #trigger>
          <im-avatar
            class="logo"
            :size="38"
            :src="userStore.avatar"
            :username="userStore.nickname"
            :square="true"
            :online="userStore.online"
            :showOnline="true"
          />
        </template>
        <AccountCard />
      </n-popover>
    </header>

    <main class="menu-main">
      <div
        v-for="nav in menus"
        :key="nav.link"
        :class="{
          'menu-items': true,
          active: isActive(nav)
        }"
        :style="{
          color: currentTheme.navText,
          '--nav-text': currentTheme.navText,
          '--nav-hover-bg': currentTheme.navTextHover,
          '--nav-active-bg': currentTheme.primaryLight,
          '--nav-active-indicator': currentTheme.primary
        }"
        @click="onClickMenu(nav)"
      >
        <!-- 消息提示 -->
        <div class="hotspot" v-if="nav.hotspot" :style="{ background: currentTheme.badgeBg }" />

        <div>
          <component
            :is="nav.icon"
            theme="outline"
            :fill="isActive(nav) ? currentTheme.primary : currentTheme.navIcon"
            :strokeWidth="2"
            :size="24"
          />
        </div>


        <span :style="{ color: currentTheme.navText }">{{ nav.title }}</span>
      </div>
    </main>

    <footer class="menu-footer">
      <div @click="onShowLogoutMenu" class="pointer" :style="{ color: currentTheme.navText }">退出</div>
    </footer>

    <!-- 退出菜单弹窗 -->
    <n-modal v-model:show="showLogoutMenu" :mask-closable="true">
      <div class="logout-menu">
        <div class="logout-item" @click="onLogout">
          <span>切换账号</span>
          <span class="logout-hint">返回登录页面</span>
        </div>
        <div class="logout-divider"></div>
        <div class="logout-item logout-quit" @click="onQuitApp">
          <span>退出程序</span>
          <span class="logout-hint">完全关闭应用</span>
        </div>
      </div>
    </n-modal>
  </section>
</template>

<style lang="less" scoped>
.menu {
  height: 100%;
  width: 100%;
  display: flex;
  flex-direction: column;
  box-sizing: border-box;
  transition: background-color 0.3s;
  /* 修复 Electron 中菜单无法点击的问题 */
  -webkit-app-region: no-drag;
  /* 移除横向滚动条 */
  overflow: hidden;

  &::-webkit-scrollbar {
    display: none;
  }

  .menu-header {
    height: 95px;
    width: 100%;
    flex-shrink: 0;
    display: flex;
    align-items: center;
    flex-direction: column;
    padding-top: 15px;
    box-sizing: border-box;
    cursor: pointer;

    .logo {
      transition: all 0.3s ease;

      &:hover {
        transform: scale(1.08);
      }
    }

    .online-text {
      margin-top: 6px;
      font-size: 11px;
      font-weight: 400;
      opacity: 0.8;
      transition: all 0.3s;
      padding: 2px 8px;
      border-radius: 8px;
      background: rgba(128, 128, 128, 0.15);

      &.online {
        color: #52c41a !important;
        opacity: 1;
        background: rgba(82, 196, 26, 0.15);
        font-weight: 500;
      }
    }
  }

  .menu-main {
    flex: auto;
    width: 100%;
    overflow: hidden;
  }

  .menu-footer {
    height: 90px;
    width: 100%;

    div {
      height: 38px;
      display: flex;
      align-items: center;
      justify-content: center;
      transition: all 0.2s;

      &:hover {
        background-color: rgba(128, 128, 128, 0.1);
      }
    }
  }
}

.menu-items {
  position: relative;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  user-select: none;
  cursor: pointer;
  font-size: 12px;
  width: 50px;
  height: 50px;
  margin: 5px auto;
  border-radius: 8px;
  transition: all 0.2s ease;

  &:hover {
    background-color: rgba(128, 128, 128, 0.1);
  }

  &.active {
    background-color: var(--nav-active-bg);

    &::before {
      content: '';
      position: absolute;
      left: 0;
      top: 50%;
      transform: translateY(-50%);
      width: 3px;
      height: 20px;
      background: var(--nav-active-indicator);
      border-radius: 0 2px 2px 0;
    }
  }

  span {
    transition: color 0.3s;
  }

  .hotspot {
    width: 5px;
    height: 5px;
    display: inline-block;
    border-radius: 5px;
    position: absolute;
    right: 5px;
    top: 9px;
    animation: notifymove 3s infinite;
    animation-direction: alternate;
    -webkit-animation: notifymove 3s infinite;
  }
}

@keyframes notifymove {
  0% {
    opacity: 1;
  }

  25% {
    opacity: 0.3;
  }

  50% {
    opacity: 1;
  }

  75% {
    opacity: 0.3;
  }

  100% {
    opacity: 1;
  }
}

@-webkit-keyframes notifymove {
  0% {
    opacity: 1;
  }

  25% {
    opacity: 0.3;
  }

  50% {
    opacity: 1;
  }

  75% {
    opacity: 0.3;
  }

  100% {
    opacity: 1;
  }
}

// 退出菜单样式
.logout-menu {
  width: 200px;
  background: var(--im-bg-color);
  border-radius: 8px;
  box-shadow: 0 4px 20px rgba(0, 0, 0, 0.15);
  overflow: hidden;
}

.logout-item {
  padding: 14px 16px;
  cursor: pointer;
  display: flex;
  flex-direction: column;
  transition: background 0.2s;

  &:hover {
    background: var(--im-hover-bg-color);
  }

  span:first-child {
    font-size: 14px;
    color: var(--im-text-color);
  }

  &.logout-quit span:first-child {
    color: #ee4444;
  }
}

.logout-hint {
  font-size: 12px;
  color: #999;
  margin-top: 2px;
}

.logout-divider {
  height: 1px;
  background: var(--border-color);
}
</style>
