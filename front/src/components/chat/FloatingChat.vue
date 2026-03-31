<script lang="ts" setup>
import { useDialogueStore, useTalkStore, useUserStore } from '@/store'
import Panel from '@/views/message/panel/Index.vue'
import Sider from '@/views/message/sider/Index.vue'
import EmbeddedContact from './EmbeddedContact.vue'
import EmbeddedSetting from './EmbeddedSetting.vue'
import { Message, People, ApplicationOne, SettingTwo, Close, Minus, Left } from '@icon-park/vue-next'

const dialogueStore = useDialogueStore()
const talkStore = useTalkStore()
const userStore = useUserStore()
const indexName = computed(() => dialogueStore.index_name)

// 窗口状态 - 默认隐藏，窗口尺寸 880x640
const isExpanded = ref(false)
const isMinimized = ref(false)
const windowSize = ref({
  width: 880,
  height: 640
})

// 最小窗口尺寸
const minWidth = 600
const minHeight = 400

// 悬浮球位置（可拖动）
const ballPosition = ref({
  x: window.innerWidth - 80,
  y: window.innerHeight - 80
})

// 窗口位置
const windowPosition = ref({
  x: Math.max(20, (window.innerWidth - 880) / 2),
  y: Math.max(20, (window.innerHeight - 640) / 2)
})

// 拖拽状态
const isDraggingBall = ref(false)
const isDraggingWindow = ref(false)
const isResizing = ref(false)
const resizeDirection = ref('')
const dragOffset = ref({ x: 0, y: 0 })
const dragStartPos = ref({ x: 0, y: 0 })
const resizeStart = ref({ x: 0, y: 0, width: 0, height: 0 })

// 左侧导航菜单
const leftMenus = [
  {
    key: 'message',
    icon: markRaw(Message),
    badge: computed(() => talkStore.talkUnreadNum > 0 ? talkStore.talkUnreadNum : 0)
  },
  {
    key: 'contact',
    icon: markRaw(People),
    badge: computed(() => (userStore.isContactApply || userStore.isGroupApply) ? 1 : 0)
  },
  {
    key: 'apps',
    icon: markRaw(ApplicationOne),
    badge: 0
  }
]

// 当前选中的菜单
const activeMenu = ref('message')

// 点击左侧菜单
const onLeftMenuClick = (menu: any) => {
  activeMenu.value = menu.key
}

// 点击设置
const onSettingsClick = () => {
  activeMenu.value = 'settings'
}

// 返回消息页面
const backToMessage = () => {
  activeMenu.value = 'message'
}

// 记录拖拽开始位置
const onBallMouseDown = (e: MouseEvent) => {
  dragStartPos.value = { x: e.clientX, y: e.clientY }
  onBallDragStart(e)
}

// 处理悬浮球点击（区分拖拽和点击）
const onBallClick = (e: MouseEvent) => {
  const moveDistance = Math.sqrt(
    Math.pow(e.clientX - dragStartPos.value.x, 2) +
    Math.pow(e.clientY - dragStartPos.value.y, 2)
  )
  // 如果移动距离小于 5 像素，认为是点击而非拖拽
  if (moveDistance < 5) {
    openWindow()
  }
}

// 打开窗口方法
const openWindow = () => {
  isExpanded.value = true
  isMinimized.value = false
}

// 关闭窗口方法
const close = () => {
  isExpanded.value = false
  isMinimized.value = false
}

// 最小化
const minimize = () => {
  isMinimized.value = true
  isExpanded.value = false
}

// 悬浮球拖拽开始
const onBallDragStart = (e: MouseEvent) => {
  isDraggingBall.value = true
  dragOffset.value = {
    x: e.clientX - ballPosition.value.x,
    y: e.clientY - ballPosition.value.y
  }
}

// 窗口拖拽开始
const onWindowDragStart = (e: MouseEvent) => {
  if ((e.target as HTMLElement).classList.contains('drag-handle')) {
    isDraggingWindow.value = true
    dragOffset.value = {
      x: e.clientX - windowPosition.value.x,
      y: e.clientY - windowPosition.value.y
    }
  }
}

// 调整大小开始
const onResizeStart = (e: MouseEvent, direction: string) => {
  e.stopPropagation()
  isResizing.value = true
  resizeDirection.value = direction
  resizeStart.value = {
    x: e.clientX,
    y: e.clientY,
    width: windowSize.value.width,
    height: windowSize.value.height
  }
}

// 拖拽中
const onDragMove = (e: MouseEvent) => {
  if (isDraggingBall.value) {
    // 悬浮球拖拽
    const newX = e.clientX - dragOffset.value.x
    const newY = e.clientY - dragOffset.value.y

    // 限制悬浮球不超出屏幕
    ballPosition.value = {
      x: Math.max(0, Math.min(newX, window.innerWidth - 60)),
      y: Math.max(0, Math.min(newY, window.innerHeight - 60))
    }
  }

  if (isDraggingWindow.value) {
    // 窗口拖拽
    const newX = e.clientX - dragOffset.value.x
    const newY = e.clientY - dragOffset.value.y

    // 限制窗口不超出屏幕
    windowPosition.value = {
      x: Math.max(0, Math.min(newX, window.innerWidth - windowSize.value.width)),
      y: Math.max(0, Math.min(newY, window.innerHeight - windowSize.value.height))
    }
  }

  if (isResizing.value) {
    // 调整大小
    const deltaX = e.clientX - resizeStart.value.x
    const deltaY = e.clientY - resizeStart.value.y

    if (resizeDirection.value.includes('e')) {
      windowSize.value.width = Math.max(minWidth, resizeStart.value.width + deltaX)
    }
    if (resizeDirection.value.includes('w')) {
      const newWidth = Math.max(minWidth, resizeStart.value.width - deltaX)
      if (newWidth !== windowSize.value.width) {
        windowPosition.value.x = resizeStart.value.x + resizeStart.value.width - newWidth
        windowSize.value.width = newWidth
      }
    }
    if (resizeDirection.value.includes('s')) {
      windowSize.value.height = Math.max(minHeight, resizeStart.value.height + deltaY)
    }
    if (resizeDirection.value.includes('n')) {
      const newHeight = Math.max(minHeight, resizeStart.value.height - deltaY)
      if (newHeight !== windowSize.value.height) {
        windowPosition.value.y = resizeStart.value.y + resizeStart.value.height - newHeight
        windowSize.value.height = newHeight
      }
    }
  }
}

// 拖拽结束
const onDragEnd = () => {
  isDraggingBall.value = false
  isDraggingWindow.value = false
  isResizing.value = false
  resizeDirection.value = ''
}

// 暴露方法给父组件
defineExpose({
  open: openWindow,
  close
})

onMounted(() => {
  document.addEventListener('mousemove', onDragMove)
  document.addEventListener('mouseup', onDragEnd)

  // 注册到全局
  if (typeof window !== 'undefined') {
    ;(window as any).floatingChat = {
      open: openWindow,
      close
    }
  }
})

onUnmounted(() => {
  document.removeEventListener('mousemove', onDragMove)
  document.removeEventListener('mouseup', onDragEnd)

  // 清理全局注册
  if (typeof window !== 'undefined') {
    delete (window as any).floatingChat
  }
})

// 当前是否有选中的会话
const hasActiveSession = computed(() => !!dialogueStore.index_name)
</script>

<template>
  <div v-if="userStore.uid" class="floating-chat-container">
    <!-- 悬浮球 (收起状态) -->
    <div
      v-if="!isExpanded && !isMinimized"
      class="floating-ball"
      :style="{
        left: ballPosition.x + 'px',
        top: ballPosition.y + 'px'
      }"
      @mousedown="onBallMouseDown"
      @click="onBallClick"
    >
      <div class="ball-icon">
        <svg width="28" height="28" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
          <path d="M20 2H4C2.9 2 2 2.9 2 4V22L6 18H20C21.1 18 22 17.1 22 16V4C22 2.9 21.1 2 20 2ZM20 16H6L4 18V4H20V16Z" fill="currentColor"/>
          <path d="M7 9H17V11H7V9ZM7 12H14V14H7V12Z" fill="currentColor"/>
        </svg>
      </div>
      <div v-if="talkStore.talkUnreadNum > 0" class="badge">
        {{ talkStore.talkUnreadNum > 99 ? '99+' : talkStore.talkUnreadNum }}
      </div>
    </div>

    <!-- 聊天窗口 (展开状态) -->
    <Transition name="chat-window">
      <div
        v-show="isExpanded"
        class="chat-window"
        :style="{
          left: windowPosition.x + 'px',
          top: windowPosition.y + 'px',
          width: windowSize.width + 'px',
          height: windowSize.height + 'px'
        }"
      >
        <!-- 调整大小手柄 -->
        <div class="resize-handle resize-n" @mousedown="onResizeStart($event, 'n')"></div>
        <div class="resize-handle resize-e" @mousedown="onResizeStart($event, 'e')"></div>
        <div class="resize-handle resize-s" @mousedown="onResizeStart($event, 's')"></div>
        <div class="resize-handle resize-w" @mousedown="onResizeStart($event, 'w')"></div>
        <div class="resize-handle resize-ne" @mousedown="onResizeStart($event, 'ne')"></div>
        <div class="resize-handle resize-nw" @mousedown="onResizeStart($event, 'nw')"></div>
        <div class="resize-handle resize-se" @mousedown="onResizeStart($event, 'se')"></div>
        <div class="resize-handle resize-sw" @mousedown="onResizeStart($event, 'sw')"></div>

        <!-- 窗口内容 -->
        <div class="window-content">
          <!-- 左侧功能菜单栏 -->
          <aside class="window-sidebar">
            <!-- 用户头像 -->
            <div class="sidebar-header">
              <div class="avatar-wrapper">
                <im-avatar
                  :size="36"
                  :src="userStore.avatar"
                  :username="userStore.nickname"
                  class="user-avatar"
                />
                <div class="online-indicator" :class="{ online: userStore.online }"></div>
              </div>
            </div>

            <!-- 导航菜单 -->
            <nav class="sidebar-nav">
              <div
                v-for="menu in leftMenus"
                :key="menu.key"
                class="nav-item"
                :class="{ active: activeMenu === menu.key }"
                @click="onLeftMenuClick(menu)"
              >
                <component
                  :is="menu.icon"
                  theme="outline"
                  :fill="activeMenu === menu.key ? '#5FA8D3' : '#fff'"
                  size="22"
                />
                <div v-if="menu.badge" class="nav-badge">
                  {{ typeof menu.badge === 'number' && menu.badge > 99 ? '99+' : menu.badge }}
                </div>
              </div>
            </nav>

            <!-- 底部设置 -->
            <div class="sidebar-footer">
              <div class="nav-item" @click="onSettingsClick">
                <SettingTwo theme="outline" fill="#fff" size="22" />
              </div>
            </div>
          </aside>

          <!-- 中间会话列表 (仅在消息页面显示) -->
          <aside v-if="activeMenu === 'message'" class="window-session-list">
            <Sider />
          </aside>

          <!-- 右侧内容区域 -->
          <main class="window-chat-area">
            <!-- 窗口标题栏 -->
            <div class="window-header drag-handle" @mousedown="onWindowDragStart">
              <div class="window-title-wrapper">
                <button 
                  v-if="activeMenu !== 'message'" 
                  class="back-btn"
                  @click="backToMessage"
                >
                  <Left theme="outline" size="18" />
                </button>
                <span class="window-title">{{ 
                  activeMenu === 'message' ? (dialogueStore.target.username || '未选择聊天') :
                  activeMenu === 'contact' ? '通讯录' :
                  activeMenu === 'settings' ? '设置' : '应用'
                }}</span>
              </div>
              <div class="window-controls">
                <button class="control-btn minimize-btn" @click="minimize">
                  <Minus theme="filled" size="14" fill="#fff" />
                </button>
                <button class="control-btn close-btn" @click="close">
                  <Close theme="filled" size="14" fill="#fff" />
                </button>
              </div>
            </div>

            <!-- 内容区域 -->
            <div class="chat-content">
              <!-- 消息页面 -->
              <template v-if="activeMenu === 'message'">
                <Panel v-if="hasActiveSession" />
                <div v-else class="empty-chat">
                  <div class="empty-content">
                    <svg width="64" height="64" viewBox="0 0 24 24" fill="none">
                      <rect x="2" y="4" width="20" height="16" rx="2" fill="#e0e0e0"/>
                      <path d="M7 9H17V11H7V9ZM7 12H14V14H7V12Z" fill="#bbb"/>
                    </svg>
                    <p>未选择聊天</p>
                  </div>
                </div>
              </template>

              <!-- 通讯录页面 -->
              <div v-else-if="activeMenu === 'contact'" class="embedded-view">
                <EmbeddedContact />
              </div>

              <!-- 设置页面 -->
              <div v-else-if="activeMenu === 'settings'" class="embedded-view">
                <EmbeddedSetting />
              </div>

              <!-- 应用页面 -->
              <div v-else-if="activeMenu === 'apps'" class="embedded-view">
                <div class="empty-chat">
                  <div class="empty-content">
                    <svg width="64" height="64" viewBox="0 0 24 24" fill="none">
                      <rect x="2" y="2" width="20" height="20" rx="4" fill="#e0e0e0"/>
                      <circle cx="8" cy="8" r="2" fill="#bbb"/>
                      <circle cx="16" cy="8" r="2" fill="#bbb"/>
                      <circle cx="8" cy="16" r="2" fill="#bbb"/>
                      <circle cx="16" cy="16" r="2" fill="#bbb"/>
                    </svg>
                    <p>应用中心</p>
                    <p class="sub-text">敬请期待</p>
                  </div>
                </div>
              </div>
            </div>
          </main>
        </div>
      </div>
    </Transition>
  </div>
</template>

<style lang="less" scoped>
.floating-chat-container {
  position: fixed;
  top: 0;
  left: 0;
  z-index: 9999;
  pointer-events: none;
}

// 悬浮球
.floating-ball {
  position: fixed;
  width: 60px;
  height: 60px;
  border-radius: 50%;
  background: linear-gradient(135deg, #8B0000 0%, #a52a2a 100%);
  box-shadow: 0 4px 20px rgba(139, 0, 0, 0.4), 0 0 0 3px rgba(255, 255, 255, 0.1);
  cursor: grab;
  pointer-events: auto;
  display: flex;
  align-items: center;
  justify-content: center;
  transition: transform 0.2s ease, box-shadow 0.3s ease;
  user-select: none;

  &:hover {
    transform: scale(1.05);
    box-shadow: 0 6px 24px rgba(139, 0, 0, 0.5), 0 0 0 4px rgba(255, 255, 255, 0.15);
  }

  &:active {
    cursor: grabbing;
    transform: scale(0.98);
  }

  .ball-icon {
    color: #ffffff;
    pointer-events: none;
  }

  .badge {
    position: absolute;
    top: -5px;
    right: -5px;
    min-width: 20px;
    height: 20px;
    padding: 0 6px;
    background: #ff4757;
    color: white;
    font-size: 12px;
    font-weight: 600;
    border-radius: 10px;
    display: flex;
    align-items: center;
    justify-content: center;
    box-shadow: 0 2px 8px rgba(255, 71, 87, 0.4);
  }
}

// 聊天窗口
.chat-window {
  position: fixed;
  background: #ffffff;
  border-radius: 8px;
  box-shadow: 0 8px 32px rgba(0, 0, 0, 0.2);
  overflow: hidden;
  pointer-events: auto;
  display: flex;
  flex-direction: column;
  min-width: 600px;
  min-height: 400px;

  // 调整大小手柄
  .resize-handle {
    position: absolute;
    z-index: 10;

    &.resize-n {
      top: 0;
      left: 10px;
      right: 10px;
      height: 6px;
      cursor: ns-resize;
    }

    &.resize-e {
      top: 10px;
      right: 0;
      bottom: 10px;
      width: 6px;
      cursor: ew-resize;
    }

    &.resize-s {
      bottom: 0;
      left: 10px;
      right: 10px;
      height: 6px;
      cursor: ns-resize;
    }

    &.resize-w {
      top: 10px;
      left: 0;
      bottom: 10px;
      width: 6px;
      cursor: ew-resize;
    }

    &.resize-ne {
      top: 0;
      right: 0;
      width: 10px;
      height: 10px;
      cursor: nesw-resize;
    }

    &.resize-nw {
      top: 0;
      left: 0;
      width: 10px;
      height: 10px;
      cursor: nwse-resize;
    }

    &.resize-se {
      bottom: 0;
      right: 0;
      width: 10px;
      height: 10px;
      cursor: nwse-resize;
    }

    &.resize-sw {
      bottom: 0;
      left: 0;
      width: 10px;
      height: 10px;
      cursor: nesw-resize;
    }
  }

  .window-content {
    flex: 1;
    display: flex;
    overflow: hidden;
  }
}

// 左侧功能菜单栏
.window-sidebar {
  width: 60px;
  background: #8B0000;
  display: flex;
  flex-direction: column;
  align-items: center;
  padding: 12px 0;
  flex-shrink: 0;

  .sidebar-header {
    margin-bottom: 16px;

    .avatar-wrapper {
      position: relative;

      .user-avatar {
        border: 2px solid rgba(255, 255, 255, 0.3);
        border-radius: 50%;
      }

      .online-indicator {
        position: absolute;
        bottom: 2px;
        right: 2px;
        width: 8px;
        height: 8px;
        border-radius: 50%;
        background: #999;
        border: 2px solid #8B0000;

        &.online {
          background: #07c160;
        }
      }
    }
  }

  .sidebar-nav {
    flex: 1;
    display: flex;
    flex-direction: column;
    gap: 4px;
  }

  .sidebar-footer {
    margin-top: auto;
    padding-top: 12px;
  }
}

// 导航项
.nav-item {
  width: 44px;
  height: 44px;
  display: flex;
  align-items: center;
  justify-content: center;
  border-radius: 8px;
  cursor: pointer;
  position: relative;
  transition: all 0.2s;

  &:hover {
    background: rgba(255, 255, 255, 0.1);
  }

  &.active {
    background: rgba(255, 255, 255, 0.15);

    &::before {
      content: '';
      position: absolute;
      left: 0;
      top: 50%;
      transform: translateY(-50%);
      width: 3px;
      height: 18px;
      background: #5FA8D3;
      border-radius: 0 2px 2px 0;
    }
  }

  .nav-badge {
    position: absolute;
    top: 4px;
    right: 4px;
    min-width: 16px;
    height: 16px;
    padding: 0 4px;
    background: #ff4d4f;
    color: white;
    font-size: 10px;
    font-weight: 600;
    border-radius: 8px;
    display: flex;
    align-items: center;
    justify-content: center;
  }
}

// 中间会话列表
.window-session-list {
  width: 260px;
  background: #ffffff;
  border-right: 1px solid #e8e8e8;
  display: flex;
  flex-direction: column;
  flex-shrink: 0;
  overflow: hidden;
}

// 嵌入视图
.embedded-view {
  flex: 1;
  overflow: auto;
  background: #f5f5f5;

  :deep(.contact-layout) {
    height: 100%;
  }

  .embedded-contact,
  .embedded-setting {
    height: 100%;
  }

  .sub-text {
    font-size: 12px;
    color: #bbb;
    margin-top: 8px;
  }
}

// 右侧聊天区域
.window-chat-area {
  flex: 1;
  display: flex;
  flex-direction: column;
  min-width: 0;
  background: #f5f5f5;

  .window-header {
    height: 48px;
    background: #f7f7f7;
    border-bottom: 1px solid #e8e8e8;
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 0 16px;
    cursor: move;
    user-select: none;
    flex-shrink: 0;

    .window-title-wrapper {
      display: flex;
      align-items: center;
      gap: 8px;

      .back-btn {
        width: 28px;
        height: 28px;
        border: none;
        background: transparent;
        border-radius: 4px;
        cursor: pointer;
        display: flex;
        align-items: center;
        justify-content: center;
        color: #666;
        transition: all 0.2s;

        &:hover {
          background: #e0e0e0;
          color: #333;
        }
      }
    }

    .window-title {
      font-size: 14px;
      color: #333;
      font-weight: 500;
    }

    .window-controls {
      display: flex;
      gap: 8px;

      .control-btn {
        width: 28px;
        height: 28px;
        border-radius: 4px;
        border: none;
        background: transparent;
        display: flex;
        align-items: center;
        justify-content: center;
        cursor: pointer;
        transition: background 0.2s;

        &:hover {
          background: #e0e0e0;
        }

        &.close-btn:hover {
          background: #ff4757;
        }
      }
    }
  }

  .chat-content {
    flex: 1;
    overflow: hidden;
    display: flex;
    flex-direction: column;

    .empty-chat {
      flex: 1;
      display: flex;
      align-items: center;
      justify-content: center;

      .empty-content {
        text-align: center;
        color: #999;

        svg {
          margin-bottom: 12px;
        }

        p {
          font-size: 13px;
        }
      }
    }
  }
}

// 动画效果
.chat-window-enter-active,
.chat-window-leave-active {
  transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
}

.chat-window-enter-from {
  opacity: 0;
  transform: scale(0.9) translateY(20px);
}

.chat-window-leave-to {
  opacity: 0;
  transform: scale(0.9) translateY(20px);
}
</style>
