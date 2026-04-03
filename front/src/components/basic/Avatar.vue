<script lang="ts" setup>
import { defaultAvatar } from '@/constant/default'
import { useThemeMode } from '@/hooks'

const { currentTheme } = useThemeMode()

defineProps({
  src: {
    type: String,
    default: ''
  },
  username: {
    type: String,
    default: ''
  },
  size: {
    type: Number,
    default: 30
  },
  fontSize: {
    type: Number,
    default: 14
  },
  bordered: {
    type: Boolean,
    default: true
  },
  shadow: {
    type: Boolean,
    default: true
  },
  square: {
    type: Boolean,
    default: false
  },
  online: {
    type: Boolean,
    default: false
  },
  showOnline: {
    type: Boolean,
    default: false
  }
})
</script>

<template>
  <div 
    class="avatar-container"
    :class="{ bordered, shadow, square, circle: !square }"
    :style="{
      '--avatar-border': currentTheme.avatarBorder,
      '--avatar-shadow': currentTheme.avatarShadow,
      '--avatar-default-bg': currentTheme.avatarDefaultBg,
      '--avatar-primary': currentTheme.primary,
      '--size': size + 'px'
    }"
  >
    <div class="avatar-inner" :style="{ width: size + 'px', height: size + 'px' }">
      <n-avatar 
        v-if="src.length" 
        :round="!square"
        :src="src" 
        :size="size" 
        :fallback-src="defaultAvatar"
        class="avatar-img"
      />

      <n-avatar
        v-else
        :round="!square"
        class="avatar-default"
        :style="{
          color: '#ffffff',
          backgroundColor: currentTheme.primary,
          fontSize: fontSize + 'px'
        }"
        :size="size"
      >
        {{ username && username.substring(0, 1) }}
      </n-avatar>
    </div>
    
    <!-- 在线状态指示器 -->
    <div v-if="showOnline" class="online-indicator" :class="{ online, square: square }"></div>
  </div>
</template>

<style lang="less" scoped>
.avatar-container {
  position: relative;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  transition: all 0.3s ease;
  
  // 圆形样式
  &.circle {
    border-radius: 50%;
    
    .avatar-inner {
      border-radius: 50%;
      overflow: hidden;
    }
    
    &.bordered {
      padding: 3px;
      background: var(--avatar-border);
      
      .avatar-inner {
        border: 2px solid #ffffff;
      }
    }
    
    .online-indicator {
      border-radius: 50%;
    }
  }
  
  // 圆角方形样式
  &.square {
    border-radius: 12px;
    
    .avatar-inner {
      border-radius: 10px;
      overflow: hidden;
    }
    
    &.bordered {
      padding: 3px;
      background: var(--avatar-border);
      
      .avatar-inner {
        border: 2px solid #ffffff;
        border-radius: 9px;
      }
    }
    
    .online-indicator {
      border-radius: 50%;
    }
  }
  
  &.shadow {
    box-shadow: var(--avatar-shadow);
  }
  
  &:hover {
    transform: scale(1.05);
    box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
  }
  
  .avatar-inner {
    flex-shrink: 0;
    transition: all 0.3s ease;
    
    :deep(.n-avatar) {
      width: 100% !important;
      height: 100% !important;
    }
  }
  
  // 在线状态指示器
  .online-indicator {
    position: absolute;
    bottom: 0;
    right: 0;
    width: 10px;
    height: 10px;
    background: #bfbfbf;
    border: 2px solid #ffffff;
    transition: all 0.3s;
    z-index: 10;
    
    &.online {
      background: #52c41a;
      box-shadow: 0 0 6px rgba(82, 196, 26, 0.6);
    }
    
    &.square {
      bottom: -2px;
      right: -2px;
    }
  }
}
</style>
