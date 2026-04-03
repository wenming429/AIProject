<script lang="ts" setup>
import { useUserStore, useSettingsStore } from '@/store'
import { Male, Female } from '@icon-park/vue-next'
import { useThemeMode } from '@/hooks'
import { computed } from 'vue'

const store = useUserStore()
const settingsStore = useSettingsStore()
const { currentTheme } = useThemeMode()

// 名片背景样式
const cardBackground = computed(() => {
  return settingsStore.getCardBackground(currentTheme.value.primary)
})
</script>

<template>
  <section class="account-card">
    <div class="card-header" :style="{ background: cardBackground }">
      <im-avatar
        :size="80"
        :src="store.avatar"
        :username="store.nickname"
        :online="store.online"
        :showOnline="true"
        class="header-avatar"
      />

      <div class="nickname text-ellipsis">
        {{ store.nickname || '未设置昵称' }}
      </div>

      <div class="gender" v-show="store.gender > 0">
        <n-icon v-if="store.gender == 1" :component="Male" color="#ffffff" />
        <n-icon v-if="store.gender == 2" :component="Female" color="#ffffff" />
      </div>
    </div>

    <div class="card-main">
      <div class="usersign pointer">
        <span style="font-weight: 600">个性签名：</span>
        <span>
          {{ store.motto || ' 编辑个签，展示我的独特态度。' }}
        </span>
      </div>
    </div>
  </section>
</template>

<style lang="less" scoped>
.account-card {
  width: 320px;
  min-height: 100px;
  background: var(--im-bg-color);
  padding-bottom: 20px;
  border-radius: 8px;
  overflow: hidden;

  .card-header {
    width: 100%;
    height: 200px;
    position: relative;
    display: flex;
    align-items: center;
    justify-content: center;
    overflow: hidden;
    transition: background 0.3s;

    &::before {
      width: 180px;
      height: 180px;
      content: '';
      background: linear-gradient(to right, rgba(255,255,255,0.15), rgba(255,255,255,0.05));
      position: absolute;
      z-index: 1;
      border-radius: 50%;
      right: -30%;
      top: -30%;
    }

    &::after {
      width: 150px;
      height: 150px;
      content: '';
      background: linear-gradient(to left, rgba(255,255,255,0.1), rgba(255,255,255,0.02));
      position: absolute;
      z-index: 1;
      border-radius: 50%;
      left: -25%;
      bottom: -20%;
    }

    .header-avatar {
      z-index: 2;
      
      :deep(.avatar-container) {
        padding: 4px;
        background: rgba(255, 255, 255, 0.35);
        box-shadow: 0 4px 15px rgba(0, 0, 0, 0.25);
        
        .avatar-inner {
          border: 3px solid #ffffff;
        }
        
        .online-indicator {
          width: 16px;
          height: 16px;
          border: 3px solid #ffffff;
          bottom: 2px;
          right: 2px;
        }
      }
      
      &:hover {
        transform: scale(1.05);
      }
    }

    .gender {
      width: 22px;
      height: 22px;
      position: absolute;
      right: 110px;
      bottom: 50px;
      display: flex;
      align-items: center;
      justify-content: center;
      border-radius: 50%;
      background: rgba(255, 255, 255, 0.2);
      z-index: 2;
    }

    .nickname {
      position: absolute;
      bottom: 15px;
      width: 70%;
      height: 30px;
      font-size: 16px;
      line-height: 30px;
      text-align: center;
      color: #ffffff;
      font-weight: 500;
      text-shadow: 0 1px 2px rgba(0, 0, 0, 0.2);
      z-index: 2;
    }
  }
}

.account-card .card-main {
  margin-top: 15px;
  min-height: 50px;
  text-align: left;
  padding: 0 16px;

  .usersign {
    min-height: 26px;
    border-radius: 8px;
    padding: 10px 12px;
    line-height: 22px;
    background: var(--im-bg-secondary, #f3f5f7);
    color: var(--im-text-color);
    font-size: 12px;
    margin-bottom: 3px;
    position: relative;
    transition: all 0.3s;

    &:hover {
      background: var(--im-hover-bg-color, #e8e8e8);
    }
  }
}

html[theme-mode='light-gray'] {
  .account-card .card-header {
    .avatar-wrapper {
      --avatar-border: rgba(255, 255, 255, 0.5);
    }
  }
}
</style>
