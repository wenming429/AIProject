<script lang="ts" setup>
import { useUserStore } from '@/store'
import { People, Peoples, PeoplesTwo, ChartGraph, Mail } from '@icon-park/vue-next'
import FriendApply from '@/views/contact/inner/FriendApply.vue'
import GroupApply from '@/views/contact/inner/GroupApply.vue'
import { reactive, computed, ref } from 'vue'

const userStore = useUserStore()
const activeTab = ref('friend')

const isNew = computed(() => {
  return userStore.isContactApply || userStore.isGroupApply
})

const menus = reactive([
  { key: 'friend', name: '我的好友', icon: markRaw(People) },
  { key: 'group', name: '我的群聊', icon: markRaw(Peoples) },
  { key: 'open-group', name: '公开群聊', icon: markRaw(PeoplesTwo) },
  { key: 'organize', name: '企业组织', icon: markRaw(ChartGraph), show: computed(() => userStore.isQiye) }
])
</script>

<template>
  <div class="embedded-contact">
    <!-- 头部 -->
    <header class="contact-header">
      <div class="title">通讯录</div>
      <n-popover trigger="click" placement="bottom-end">
        <template #trigger>
          <n-badge dot :show="isNew" :offset="[-5, 5]">
            <div class="action-btn">
              <n-icon :component="Mail" :size="18" />
              <span>好友(群)通知</span>
            </div>
          </n-badge>
        </template>
        <n-tabs type="line" justify-content="start" pane-style="height: 400px; width: 320px;">
          <n-tab-pane name="friend" tab="好友通知">
            <n-scrollbar style="height: 400px">
              <FriendApply />
            </n-scrollbar>
          </n-tab-pane>
          <n-tab-pane name="group" tab="入群通知">
            <n-scrollbar style="height: 400px">
              <GroupApply />
            </n-scrollbar>
          </n-tab-pane>
        </n-tabs>
      </n-popover>
    </header>

    <!-- 内容区 -->
    <div class="contact-body">
      <!-- 左侧子菜单 -->
      <aside class="contact-sidebar">
        <div
          v-for="menu in menus"
          :key="menu.key"
          v-show="menu.show !== false"
          class="menu-item"
          :class="{ active: activeTab === menu.key }"
          @click="activeTab = menu.key"
        >
          <n-icon :size="16" :component="menu.icon" />
          <span>{{ menu.name }}</span>
        </div>
      </aside>

      <!-- 右侧内容 -->
      <main class="contact-content">
        <n-scrollbar>
          <!-- 我的好友 -->
          <div v-if="activeTab === 'friend'" class="tab-panel">
            <FriendList />
          </div>
          <!-- 我的群聊 -->
          <div v-else-if="activeTab === 'group'" class="tab-panel">
            <GroupList />
          </div>
          <!-- 公开群聊 -->
          <div v-else-if="activeTab === 'open-group'" class="tab-panel">
            <OpenGroupList />
          </div>
          <!-- 企业组织 -->
          <div v-else-if="activeTab === 'organize'" class="tab-panel">
            <OrganizeList />
          </div>
        </n-scrollbar>
      </main>
    </div>
  </div>
</template>

<script lang="ts">
// 导入子组件
import FriendList from '@/views/contact/friend.vue'
import GroupList from '@/views/contact/group.vue'
import OpenGroupList from '@/views/contact/open-group.vue'
import OrganizeList from '@/views/contact/organize.vue'

export default {
  components: {
    FriendList,
    GroupList,
    OpenGroupList,
    OrganizeList
  }
}
</script>

<style lang="less" scoped>
.embedded-contact {
  height: 100%;
  display: flex;
  flex-direction: column;
  background: #f5f5f5;

  .contact-header {
    height: 48px;
    background: #fff;
    border-bottom: 1px solid #e8e8e8;
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 0 16px;
    flex-shrink: 0;

    .title {
      font-size: 16px;
      font-weight: 500;
      color: #333;
    }

    .action-btn {
      display: flex;
      align-items: center;
      gap: 6px;
      padding: 6px 12px;
      border-radius: 4px;
      cursor: pointer;
      color: #666;
      font-size: 13px;
      transition: all 0.2s;

      &:hover {
        background: #f0f0f0;
        color: #333;
      }
    }
  }

  .contact-body {
    flex: 1;
    display: flex;
    overflow: hidden;

    .contact-sidebar {
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

    .contact-content {
      flex: 1;
      overflow: hidden;

      .tab-panel {
        padding: 12px;
      }
    }
  }
}
</style>
