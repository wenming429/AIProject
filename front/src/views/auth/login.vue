<script lang="ts" setup>
import { fetchAuthLogin } from '@/apis/api'
import { sync } from '@/apis/request'
import ws from '@/connect'
import { useInject } from '@/hooks'
import { useUserStore } from '@/store'
import { setToken } from '@/utils/auth.ts'
import { rsaEncrypt } from '@/utils/rsa'
import { playMusic } from '@/utils/talk'
import { onBeforeUnmount } from 'vue'

const { message } = useInject()
const userStore = useUserStore()
const route = useRoute()
const router = useRouter()
const formRef = ref()
const rules = {
  username: {
    required: true,
    trigger: ['blur', 'input'],
    message: '用户名不能为空'
  },
  password: {
    required: true,
    trigger: ['blur', 'input'],
    message: '密码不能为空'
  }
}

const loading = ref(false)

const model = reactive({
  username: '',
  password: ''
})

const onLogin = async () => {
  sync(
    async () => {
      const data = await fetchAuthLogin({
        username: model.username,
        password: rsaEncrypt(model.password),
        platform: 'web'
      })

      setToken(data.access_token, data.expires_in)
      ws.connect()
      message.success('登录成功，即将进入系统')
      userStore.loadSetting()

      router.push(route.params?.redirect || ('/' as any))
    },
    { loading }
  )
}

const onValidate = (e: Event) => {
  e.preventDefault()

  // 谷歌浏览器提示音需要用户主动交互才能播放，登录入口主动交互一次，后面消息提示音就能正常播放了
  playMusic(true)

  formRef.value.validate((errors: any) => !errors && onLogin())
}

const onClickAccount = (type: number) => {
  if (type == 1) {
    model.username = 'shulifang'
    model.password = 'admin123'
  } else {
    model.username = 'ningxiaoying'
    model.password = 'admin123'
  }

  onLogin()
}

// 窗口控制功能
const onMinimize = () => {
  if ((window as any).$electron?.minimize) {
    ;(window as any).$electron.minimize()
  }
}

const onMaximize = () => {
  if ((window as any).$electron?.maximize) {
    ;(window as any).$electron.maximize()
  }
}

const onClose = () => {
  if ((window as any).$electron?.quitApp) {
    ;(window as any).$electron.quitApp()
  } else {
    window.close()
  }
}

// 组件卸载时清理
onBeforeUnmount(() => {
  // 清理可能残留的 DOM 元素
  const existingOverlay = document.querySelector('.n-modal-mask')
  if (existingOverlay) {
    existingOverlay.remove()
  }
})

// 导入 onBeforeUnmount
import { onBeforeUnmount } from 'vue'
</script>

<template>
  <section class="el-container is-vertical login-box login">
    <!-- 窗口控制栏 -->
    <header class="window-controls">
      <div class="window-title">用户登录</div>
      <div class="window-buttons">
        <div class="window-btn minimize" @click="onMinimize" title="最小化">
          <svg viewBox="0 0 24 24" width="12" height="12">
            <path fill="currentColor" d="M19 13H5v-2h14v2z"/>
          </svg>
        </div>
        <div class="window-btn maximize" @click="onMaximize" title="最大化">
          <svg viewBox="0 0 24 24" width="12" height="12">
            <path fill="currentColor" d="M19 3H5c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h14c1.1 0 2-.9 2-2V5c0-1.1-.9-2-2-2zm0 16H5V5h14v14z"/>
          </svg>
        </div>
        <div class="window-btn close" @click="onClose" title="关闭">
          <svg viewBox="0 0 24 24" width="12" height="12">
            <path fill="currentColor" d="M19 6.41L17.59 5 12 10.59 6.41 5 5 6.41 10.59 12 5 17.59 6.41 19 12 13.41 17.59 19 19 17.59 13.41 12z"/>
          </svg>
        </div>
      </div>
    </header>

    <main class="el-main">
      <!-- 用户头像 -->
      <div class="avatar-container">
        <img src="@/assets/image/avatar.png" alt="用户头像" class="avatar" />
      </div>

      <n-form ref="formRef" size="large" :model="model" :rules="rules">
        <n-form-item path="username" :show-label="false">
          <n-input
            placeholder="请输入用户名"
            v-model:value="model.username"
            @keydown.enter="onValidate"
          />
        </n-form-item>

        <n-form-item path="password" :show-label="false">
          <n-input
            placeholder="请输入密码"
            type="password"
            show-password-on="click"
            v-model:value="model.password"
            @keydown.enter="onValidate"
          />
        </n-form-item>

        <n-space justify="center" style="margin-top: 12px">
          <n-button text color="#409eff" @click="onClickAccount(1)"> 账号1 </n-button>
          <n-button text color="#409eff" @click="onClickAccount(2)"> 账号2 </n-button>
        </n-space>

        <n-button
          type="primary"
          size="large"
          block
          text-color="#ffffff"
          class="mt-t20"
          @click="onValidate"
          :loading="loading"
        >
          登录
        </n-button>
      </n-form>
    </main>
  </section>
</template>

<style lang="less" scoped>
@import '@/assets/css/login.less';

// 固定窗口尺寸
.login-box {
  width: 360px;
  height: 500px;
  position: fixed;
  top: 50%;
  left: 50%;
  transform: translate(-50%, -50%);
  z-index: 1000;
  background: var(--im-bg-color);
}

// 确保输入框始终可点击
:deep(.n-input),
:deep(.n-button) {
  pointer-events: auto !important;
  z-index: 1;
}

// 窗口控制栏
.window-controls {
  height: 36px;
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 0 12px;
  background: #f5f5f5;
  border-radius: 10px 10px 0 0;

  .window-title {
    font-size: 14px;
    color: #333;
    font-weight: 500;
  }

  .window-buttons {
    display: flex;
    gap: 8px;
  }

  .window-btn {
    width: 28px;
    height: 28px;
    border-radius: 50%;
    display: flex;
    align-items: center;
    justify-content: center;
    cursor: pointer;
    transition: background 0.2s;
    color: #666;

    &:hover {
      background: #e0e0e0;
    }

    &.close:hover {
      background: #ff5f56;
      color: #fff;
    }
  }
}

.box-header {
  height: 60px;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 20px;
  font-weight: 500;
  color: var(--im-text-color);
}

.avatar-container {
  display: flex;
  justify-content: center;
  margin-bottom: 24px;

  .avatar {
    width: 80px;
    height: 80px;
    border-radius: 50%;
    object-fit: cover;
    border: 3px solid var(--im-primary-color);
    box-shadow: 0 2px 10px rgba(0, 0, 0, 0.1);
  }
}

.mt-t20 {
  margin-top: 20px;
}
</style>