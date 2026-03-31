<script lang="ts" setup>
import { useSettingsStore, useTalkStore, useUserStore } from '@/store'
import { GithubOne, Message, NotebookOne, People, SettingTwo } from '@icon-park/vue-next'
import AccountCard from './AccountCard.vue'
import { NModal } from 'naive-ui'

const userStore = useUserStore()
const talkStore = useTalkStore()
const router = useRouter()

const settingsStore = useSettingsStore()

const color = computed(() => {
  return settingsStore.currentThemeMode == 'dark' ? '#ffffff' : '#333'
})

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

const onClickMenu = (menu) => {
  if (menu.external) {
    window.open(menu.link)
    return
  }
  router.push(menu.link)
}

const isActive = (menu) => {
  return router.currentRoute.value.path.indexOf(menu.link) >= 0
}
</script>

<template>
  <section class="menu">
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
            :size="35"
            :src="userStore.avatar"
            :username="userStore.nickname"
          />
        </template>
        <AccountCard />
      </n-popover>

      <span class="online-status" :class="{ online: userStore.online }">
        {{ userStore.online ? '在线' : '连接中...' }}
      </span>
    </header>

    <main class="menu-main">
      <div
        v-for="nav in menus"
        :key="nav.link"
        :class="{
          'menu-items': true,
          active: isActive(nav)
        }"
        @click="onClickMenu(nav)"
      >
        <!-- 消息提示 -->
        <div class="hotspot" v-if="nav.hotspot" />

        <div>
          <component
            :is="nav.icon"
            :theme="isActive(nav) ? 'filled' : 'outline'"
            :fill="isActive(nav) ? '#1890ff' : color"
            :strokeWidth="2"
            :size="22"
          />
        </div>

        <span>{{ nav.title }}</span>
      </div>
    </main>

    <footer class="menu-footer">
      <div>
        <a class="pointer" href="https://github.com/gzydong/LumenIM" target="_blank">
          <github-one theme="outline" size="22" :fill="color" :strokeWidth="2" />
        </a>
      </div>
      <div @click="onShowLogoutMenu" class="pointer">退出</div>
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

  .menu-header {
    height: 90px;
    width: 100%;
    flex-shrink: 0;
    display: flex;
    align-items: center;
    flex-direction: column;
    padding-top: 18px;
    box-sizing: border-box;
    cursor: pointer;

    .online-status {
      margin-top: 5px;
      font-size: 13px;
      font-weight: 300;
      color: rgb(185, 181, 181);

      &.online {
        color: #65c468;
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
  border-radius: 3px;
  font-size: 12px;
  width: 54px;
  height: 54px;
  margin: 8px auto;
  border-radius: 10px;

  .hotspot {
    width: 5px;
    height: 5px;
    --hotspot: #ff1e1e;
    background: var(--hotspot);
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
    background: var(--hotspot);
  }

  25% {
    background: transparent;
  }

  50% {
    background: var(--hotspot);
  }

  75% {
    background: transparent;
  }

  100% {
    background: var(--hotspot);
  }
}

@-webkit-keyframes notifymove {
  0% {
    background: #ff1e1e;
  }

  25% {
    background: transparent;
  }

  50% {
    background: #ff1e1e;
  }

  75% {
    background: transparent;
  }

  100% {
    background: #ff1e1e;
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
  background: var(--im-border-color);
}
</style>
