<script lang="ts" setup>
import { reactive, ref } from 'vue'
import { User, Protect, Remind, Tool, LinkThree } from '@icon-park/vue-next'
import Detail from '@/views/setting/detail.vue'
import Security from '@/views/setting/security.vue'
import Notification from '@/views/setting/notification.vue'
import Personalize from '@/views/setting/personalize.vue'
import Binding from '@/views/setting/binding.vue'

const activeTab = ref('detail')

const menus = reactive([
  { key: 'detail', name: '我的详情', icon: markRaw(User) },
  { key: 'security', name: '账号安全', icon: markRaw(Protect) },
  { key: 'notification', name: '消息通知', icon: markRaw(Remind) },
  { key: 'personalize', name: '个性化', icon: markRaw(Tool) },
  { key: 'binding', name: '账号绑定', icon: markRaw(LinkThree) }
])
</script>

<template>
  <div class="embedded-setting">
    <!-- 头部 -->
    <header class="setting-header">
      <div class="title">设置</div>
    </header>

    <!-- 内容区 -->
    <div class="setting-body">
      <!-- 左侧子菜单 -->
      <aside class="setting-sidebar">
        <div
          v-for="menu in menus"
          :key="menu.key"
          class="menu-item"
          :class="{ active: activeTab === menu.key }"
          @click="activeTab = menu.key"
        >
          <n-icon :size="16" :component="menu.icon" />
          <span>{{ menu.name }}</span>
        </div>
      </aside>

      <!-- 右侧内容 -->
      <main class="setting-content">
        <n-scrollbar>
          <div class="tab-panel">
            <Detail v-if="activeTab === 'detail'" />
            <Security v-else-if="activeTab === 'security'" />
            <Notification v-else-if="activeTab === 'notification'" />
            <Personalize v-else-if="activeTab === 'personalize'" />
            <Binding v-else-if="activeTab === 'binding'" />
          </div>
        </n-scrollbar>
      </main>
    </div>
  </div>
</template>

<style lang="less" scoped>
.embedded-setting {
  height: 100%;
  display: flex;
  flex-direction: column;
  background: #f5f5f5;

  .setting-header {
    height: 48px;
    background: #fff;
    border-bottom: 1px solid #e8e8e8;
    display: flex;
    align-items: center;
    padding: 0 16px;
    flex-shrink: 0;

    .title {
      font-size: 16px;
      font-weight: 500;
      color: #333;
    }
  }

  .setting-body {
    flex: 1;
    display: flex;
    overflow: hidden;

    .setting-sidebar {
      width: 150px;
      background: #fff;
      border-right: 1px solid #e8e8e8;
      padding: 8px;
      flex-shrink: 0;

      .menu-item {
        height: 36px;
        padding: 0 12px;
        display: flex;
        align-items: center;
        gap: 10px;
        border-radius: 4px;
        cursor: pointer;
        font-size: 13px;
        color: #333;
        transition: all 0.2s;
        margin-bottom: 4px;

        &:hover {
          background: #f5f5f5;
        }

        &.active {
          background: #8B0000;
          color: #fff;
        }
      }
    }

    .setting-content {
      flex: 1;
      overflow: hidden;
      background: #fff;

      .tab-panel {
        padding: 20px;
      }
    }
  }
}
</style>
