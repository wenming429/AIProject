<script lang="ts" setup>
import { ArrowUp, ArrowDown, CloseRemind } from '@icon-park/vue-next'
import Xtime from '@/components/basic/Xtime.vue'
import { ISession } from '@/types/chat'
import { useThemeMode } from '@/hooks'

const { currentTheme } = useThemeMode()

const emit = defineEmits(['tab-talk', 'top-talk'])

defineProps<{
  data: ISession
  avatar: String
  username: String
  active: Boolean
}>()
</script>

<template>
  <div 
    class="talk-item pointer" 
    :class="{ actived: active }" 
    @click="emit('tab-talk', data)"
    :style="{
      '--item-bg': currentTheme.messageItemBg,
      '--item-hover': currentTheme.messageItemHover,
      '--item-active': currentTheme.messageItemActive,
      '--text-primary': currentTheme.messageText,
      '--text-secondary': currentTheme.messageTextSecondary,
      '--text-time': currentTheme.messageTime,
      '--badge-bg': currentTheme.badgeBg,
      '--badge-text': currentTheme.badgeText,
      '--primary-color': currentTheme.primary,
      '--avatar-border': currentTheme.avatarBorder,
      '--avatar-shadow': currentTheme.avatarShadow
    }"
  >
    <div class="talk-item-avatar">
      <im-avatar :src="avatar" :size="34" :username="data.name" />
      <div class="top-mask" @click.stop="emit('top-talk', data)">
        <n-icon :component="data.is_top === 1 ? ArrowDown : ArrowUp" />
      </div>
    </div>

    <div class="talk-item-content">
      <div class="header">
        <div class="title">
          <span class="nickname">{{ username }}</span>
          <span class="badge top" v-show="data.is_top === 1">顶</span>
          <span class="badge roboot" v-show="data.is_robot === 1">助</span>
          <span class="badge group" v-show="data.talk_mode === 2">群</span>
        </div>
        <div class="datetime"><Xtime :time="data.updated_at" /></div>
      </div>

      <div class="content">
        <div class="text">
          <template v-if="!active && data.draft_text">
            <span class="draft">[草稿]</span>
            <span class="detail" v-html="data.draft_text" />
          </template>
          <template v-else>
            <span class="detail" v-html="data.msg_text" />
          </template>
        </div>

        <div class="tip">
          <div v-if="data.is_disturb === 1" class="disturb">
            <n-icon :component="CloseRemind" />
          </div>

          <div v-else class="unread" v-show="data.unread_num">
            <span class="unread-badge">
              {{ data.unread_num > 99 ? '99+' : data.unread_num }}
            </span>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<style lang="less" scoped>
.talk-item {
  padding: 8px 10px;
  height: 50px;
  display: flex;
  align-items: center;
  background-color: var(--item-bg);
  transition: all 0.2s ease;

  &-avatar {
    width: 40px;
    height: 40px;
    display: flex;
    justify-content: center;
    align-items: center;
    user-select: none;
    transition: all 0.3s ease;
    position: relative;
    
    :deep(.avatar-container) {
      &.circle {
        border-radius: 50%;
      }
    }

    .top-mask {
      width: 34px;
      height: 34px;
      border-radius: 50%;
      background-color: rgba(22, 25, 29, 0.6);
      position: absolute;
      top: 50%;
      left: 50%;
      transform: translate(-50%, -50%);
      color: #ffffff;
      display: none;
      align-items: center;
      justify-content: center;
      z-index: 10;
    }

    &:hover .top-mask {
      display: flex;
    }
  }

  &-content {
    height: 40px;
    display: flex;
    align-content: center;
    flex-direction: column;
    flex: 1;
    margin-left: 10px;
    overflow: hidden;

    .header {
      width: 100%;
      height: 20px;
      display: flex;
      align-items: center;

      .title {
        color: var(--text-primary);
        font-size: 14px;
        line-height: 20px;
        flex: 1;
        display: flex;
        overflow: hidden;

        .nickname {
          white-space: nowrap;
          overflow: hidden;
          text-overflow: ellipsis;
          margin-right: 5px;
        }
      }

      .datetime {
        color: var(--text-time);
        font-size: 12px;
        margin-left: 10px;
        user-select: none;
      }
    }

    .content {
      width: 100%;
      height: 20px;
      display: flex;
      align-items: center;
      justify-content: space-between;

      .text {
        overflow: hidden;
        font-weight: 300;
        font-size: 12px;
        color: var(--text-secondary);
        display: flex;

        .draft {
          color: var(--primary-color);
          padding-right: 3px;
          flex-shrink: 0;
          font-weight: 500;
        }

        .online {
          color: #8bc34a;
          padding-right: 3px;
          flex-shrink: 0;
        }

        .detail {
          white-space: nowrap;
          overflow: hidden;
          text-overflow: ellipsis;
        }
      }

      .tip {
        height: inherit;
        display: flex;
        padding-left: 5px;
        align-items: center;

        .unread {
          color: var(--text-secondary);
          font-size: 12px;
          user-select: none;

          .unread-badge {
            background-color: var(--badge-bg);
            color: var(--badge-text);
            border-radius: 10px;
            padding: 1px 6px;
            font-size: 11px;
            font-weight: 500;
          }
        }

        .disturb {
          color: var(--text-secondary);
          font-size: 12px;
          user-select: none;
        }
      }
    }
  }

  &:hover {
    background-color: var(--item-hover);
  }

  &.actived {
    background-color: var(--item-active);
  }
}

.badge {
  font-size: 10px;
  padding: 0 4px;
  border-radius: 3px;
  margin-left: 4px;
  flex-shrink: 0;

  &.top {
    color: var(--primary-color);
    background-color: var(--im-primary-light, rgba(191, 0, 8, 0.1));
  }

  &.roboot {
    color: #dc9b04;
    background-color: #faf1d1;
  }

  &.group {
    color: #3370ff;
    background-color: #e1eaff;
  }
}

// 适配不同主题
html[theme-mode='huaxia-red'] {
  .talk-item {
    --im-primary-light: rgba(191, 0, 8, 0.1);
  }
}

html[theme-mode='light-gray'] {
  .talk-item {
    --im-primary-light: rgba(91, 107, 121, 0.1);
  }
}
</style>
