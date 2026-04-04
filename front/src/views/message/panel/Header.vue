<script lang="ts" setup>
import { Announcement, MenuFoldOne, MenuUnfoldOne, More, PeoplePlusOne } from '@icon-park/vue-next'
import { useThemeMode } from '@/hooks'

const { currentTheme } = useThemeMode()

const emit = defineEmits(['evnet', 'changeSessionMenu'])

const props = defineProps({
  talkMode: {
    type: Number,
    default: 1
  },
  username: {
    type: String,
    default: ''
  },
  online: {
    type: Boolean,
    default: false
  },
  keyboard: {
    type: Boolean,
    default: false
  },
  num: {
    type: Number,
    default: 0
  },
  menu: {
    type: Boolean,
    default: false
  },
  description: {
    type: String,
    default: ''
  }
})

const onSetMenu = () => {
  emit('changeSessionMenu', !props.menu)
}
</script>

<template>
  <header 
    class="el-header panel-header"
    :style="{
      '--header-bg': currentTheme.chatHeaderBg,
      '--header-border': currentTheme.chatHeaderBorder,
      '--text-primary': currentTheme.textPrimary,
      '--text-secondary': currentTheme.textSecondary,
      '--primary-color': currentTheme.primary,
      '--tag-group': currentTheme.primary,
      '--tag-friend': '#f97348'
    }"
  >
    <div class="menu border-right pointer" @click="onSetMenu">
      <n-icon :component="menu ? MenuUnfoldOne : MenuFoldOne" :size="22" />
    </div>

    <div class="module left-module">
      <span class="tag" v-show="talkMode == 2"> 群 </span>
      <span class="tag red" v-show="talkMode == 1"> 友 </span>
      <span class="nickname text-ellipsis" :class="{ opacity: talkMode == 1 && !online }"
        >{{ username }} <span v-show="talkMode == 2 && num">({{ num }} 人)</span></span
      >
      <span class="keyboard" v-show="keyboard">对方正在输入...</span>
      <p class="desc text-ellipsis" v-show="description.length">
        {{ description }}
      </p>
    </div>

    <div class="module right-module">
      <n-popover trigger="hover">
        <template #trigger>
          <n-icon
            class="icon"
            v-show="talkMode == 2"
            :component="Announcement"
            :size="18"
            @click="emit('evnet', 'announcement')"
          />
        </template>
        群公告
      </n-popover>

      <n-popover trigger="hover">
        <template #trigger>
          <n-icon
            class="icon"
            :component="PeoplePlusOne"
            :size="18"
            @click="emit('evnet', 'addGroup')"
          />
        </template>
        {{ talkMode === 1 ? '发起群聊' : '邀请好友' }}
      </n-popover>

      <n-popover trigger="hover">
        <template #trigger>
          <n-icon
            class="icon"
            v-show="talkMode == 2"
            :component="More"
            :size="18"
            @click="emit('evnet', 'group')"
          />
        </template>
        群详情
      </n-popover>
    </div>
  </header>
</template>

<style lang="less" scoped>
.panel-header {
  height: 60px;
  padding: 0 15px;
  display: flex;
  align-items: center;
  justify-content: space-between;
  box-sizing: border-box;
  -webkit-app-region: drag;
  position: relative;
  background-color: var(--header-bg);
  border-bottom: 1px solid var(--header-border);
  transition: all 0.3s;

  .menu {
    width: 50px;
    position: absolute;
    display: flex;
    align-items: center;
    left: 0;
    justify-content: center;
    color: var(--text-secondary);
    transition: color 0.3s;
    /* 修复 Electron 中菜单按钮无法点击的问题 */
    -webkit-app-region: no-drag;

    &:hover {
      color: var(--primary-color);
    }
  }

  .module {
    height: 100%;
    display: flex;
    align-items: center;
  }

  .left-module {
    padding-right: 5px;
    margin-left: 50px;
    position: relative;
    flex: 1 auto;

    .nickname {
      color: var(--text-primary);
      font-weight: 500;
      font-size: 15px;
      transition: color 0.3s;
    }

    .opacity {
      opacity: 0.7;
    }

    .keyboard {
      animation: inputfade 1s infinite;
      -webkit-animation: inputfade 1s infinite;
      margin-left: 5px;
      font-size: 12px;
      color: var(--primary-color);
    }

    .desc {
      position: absolute;
      left: 27px;
      bottom: 0;
      width: 80%;
      font-size: 12px;
      color: var(--text-secondary);
      opacity: 0.7;
      transform: scale(0.9);
      transform-origin: left;
    }
  }

  .right-module {
    display: flex;
    justify-content: flex-end;
    align-items: center;
    /* 修复 Electron 中功能键无法点击的问题 */
    -webkit-app-region: no-drag;

    .icon {
      cursor: pointer;
      margin: 0 8px;
      color: var(--text-secondary);
      transition: all 0.2s;

      &:hover {
        color: var(--primary-color);
        transform: scale(1.1);
      }
    }
  }
}

/* css 动画 */
@keyframes inputfade {
  from {
    opacity: 1;
  }

  50% {
    opacity: 0.4;
  }

  to {
    opacity: 1;
  }
}

@-webkit-keyframes inputfade {
  from {
    opacity: 1;
  }

  50% {
    opacity: 0.4;
  }

  to {
    opacity: 1;
  }
}

.tag {
  height: 18px;
  line-height: 18px;
  padding: 1px 5px;
  font-size: 10px;
  color: white;
  border-radius: 3px;
  margin-right: 8px;
  flex-shrink: 0;
  font-weight: 500;

  &:not(.red) {
    background: var(--tag-group);
  }

  &.red {
    background: var(--tag-friend);
  }
}
</style>
