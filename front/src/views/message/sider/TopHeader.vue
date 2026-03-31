<script lang="ts" setup>
import type { ISession } from '@/types/chat'
import { Close } from '@icon-park/vue-next'

const emit = defineEmits(['tab-talk', 'unpin-talk'])

const props = defineProps<{
  indexName: String
  items: ISession[]
}>()

// 取消置顶
function onUnpin(e: Event, item: ISession) {
  e.stopPropagation()
  emit('unpin-talk', item)
}
</script>

<template>
  <div class="top-section">
    <div class="top-header">
      <div
        v-for="item in items"
        :key="item.index_name"
        class="top-item"
        :class="{ active: item.index_name == indexName }"
        @click="emit('tab-talk', item)"
      >
        <!-- 头像 -->
        <div class="avatar-wrapper">
          <im-avatar :src="item.avatar" :size="40" :username="item.name" />
          <!-- 未读数 -->
          <span v-if="item.unread_num > 0" class="unread-badge">
            {{ item.unread_num > 99 ? '99+' : item.unread_num }}
          </span>
          <!-- 取消置顶按钮 -->
          <div class="unpin-btn" @click.stop="onUnpin($event, item)">
            <n-icon :component="Close" size="10" />
          </div>
        </div>
        <!-- 名称 -->
        <span class="name">{{ item.remark || item.name }}</span>
      </div>
    </div>
  </div>
</template>

<style lang="less" scoped>
.top-section {
  background: #f5f5f5;
  border-bottom: 1px solid #e0e0e0;
  padding: 8px 0;
}

.top-header {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
  padding: 0 12px;
  max-height: 120px;
  overflow-y: auto;

  // 隐藏滚动条
  &::-webkit-scrollbar {
    display: none;
  }

  .top-item {
    display: flex;
    flex-direction: column;
    align-items: center;
    width: 56px;
    cursor: pointer;
    position: relative;
    padding: 4px;
    border-radius: 8px;
    transition: all 0.2s;

    &:hover {
      background: rgba(0, 0, 0, 0.05);

      .unpin-btn {
        opacity: 1;
      }
    }

    &.active {
      background: rgba(24, 144, 255, 0.1);

      .name {
        color: #1890ff;
      }
    }

    .avatar-wrapper {
      position: relative;
      width: 40px;
      height: 40px;
      margin-bottom: 4px;

      .unread-badge {
        position: absolute;
        top: -4px;
        right: -4px;
        min-width: 16px;
        height: 16px;
        background: #ff4d4f;
        color: #fff;
        font-size: 10px;
        border-radius: 8px;
        display: flex;
        align-items: center;
        justify-content: center;
        padding: 0 4px;
        box-shadow: 0 1px 2px rgba(0, 0, 0, 0.2);
      }

      .unpin-btn {
        position: absolute;
        top: -4px;
        right: -4px;
        width: 14px;
        height: 14px;
        background: rgba(0, 0, 0, 0.5);
        color: #fff;
        border-radius: 50%;
        display: flex;
        align-items: center;
        justify-content: center;
        opacity: 0;
        transition: opacity 0.2s;
        cursor: pointer;

        &:hover {
          background: rgba(255, 77, 79, 0.9);
        }
      }
    }

    .name {
      font-size: 11px;
      color: #666;
      text-align: center;
      width: 100%;
      overflow: hidden;
      text-overflow: ellipsis;
      white-space: nowrap;
      line-height: 16px;
    }
  }
}

// 暗黑模式
html[theme-mode='dark'] {
  .top-section {
    background: #1a1a1a;
    border-bottom-color: #333;
  }

  .top-header {
    .top-item {
      &:hover {
        background: rgba(255, 255, 255, 0.05);
      }

      &.active {
        background: rgba(24, 144, 255, 0.15);
      }

      .name {
        color: #bbb;
      }

      &.active .name {
        color: #4da6ff;
      }
    }
  }
}
</style>
