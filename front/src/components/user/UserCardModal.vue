<script lang="ts" setup>
import {
  fetchContactApplyCreate,
  fetchContactChangeGroup,
  fetchContactDetail,
  fetchContactEditRemark,
  fetchContactGroupList
} from '@/apis/api'
import { fetchApi } from '@/apis/request'
import { ContactConst } from '@/constant/event-bus.ts'
import { useInject, useThemeMode } from '@/hooks'
import { useSettingsStore, useTalkStore } from '@/store'
import { bus } from '@/utils'
import { formatPhone } from '@/utils/string'
import { CloseOne, Female, Male, SendOne } from '@icon-park/vue-next'
import { computed } from 'vue'

const { message } = useInject()
const router = useRouter()
const talkStore = useTalkStore()
const { currentTheme } = useThemeMode()
const settingsStore = useSettingsStore()

const emit = defineEmits(['close'])

const props = defineProps({
  userId: {
    type: Number,
    default: 0
  },
  loginUserId: {
    type: Number,
    default: 0
  }
})

const loading = ref(true)
const isOpenFrom = ref(false)
const applyRemark = ref('')
const friendRemark = ref('')
const userInfo: any = reactive({
  user_id: 0,
  avatar: '',
  gender: 0,
  mobile: '',
  motto: '',
  nickname: '',
  email: '',
  relation: 1, // 关系 1陌生人 2好友 3企业同事 4本人
  contact_group_id: 0,
  contact_remark: ''
})

const genders = {
  0: '-',
  1: '男',
  2: '女',
  3: '未知'
}

const editCardPopover: any = ref(false)
const options = ref<any>([])
const groupName = computed(() => {
  const item = options.value.find((item: any) => {
    return item.key == userInfo.contact_group_id
  })

  return item?.label || '-'
})

// 卡片背景样式 - 使用主题色或自定义名片主题色
const cardBackground = computed(() => {
  // 优先使用用户设置的名片主题色
  if (settingsStore.useCustomCardTheme && settingsStore.cardThemeGradient) {
    return settingsStore.cardThemeGradient
  }
  // 否则使用当前主题色
  return `linear-gradient(135deg, ${currentTheme.value.primary} 0%, ${lightenColor(currentTheme.value.primary, 20)} 100%)`
})

//  lighten color helper
const lightenColor = (color: string, percent: number): string => {
  const num = parseInt(color.replace('#', ''), 16)
  const amt = Math.round(2.55 * percent)
  const R = (num >> 16) + amt
  const G = ((num >> 8) & 0x00ff) + amt
  const B = (num & 0x0000ff) + amt
  return '#' + (
    0x1000000 +
    (R < 255 ? (R < 1 ? 0 : R) : 255) * 0x10000 +
    (G < 255 ? (G < 1 ? 0 : G) : 255) * 0x100 +
    (B < 255 ? (B < 1 ? 0 : B) : 255)
  ).toString(16).slice(1)
}

const onLoadUser = async () => {
  const [err, data] = await fetchApi(fetchContactDetail, { user_id: props.userId }, { loading })

  if (err) return

  Object.assign(userInfo, {
    user_id: data.user_id,
    avatar: data.avatar,
    gender: data.gender,
    mobile: data.mobile,
    motto: data.motto,
    nickname: data.nickname,
    email: data.email,
    relation: data.relation,
    contact_group_id: data.contact_group_id,
    contact_remark: data.contact_remark
  })

  friendRemark.value = data.contact_remark
}

const onLoadUserGroup = async () => {
  const [err, data] = await fetchApi(fetchContactGroupList, {})
  if (err) return

  let items = data.items || []

  options.value = []
  for (const iter of items) {
    options.value.push({ label: iter.name, key: iter.id })
  }
}

const onToTalk = () => {
  talkStore.toTalk(1, props.userId, router)
  emit('close')
}

const onJoinContact = async () => {
  if (!applyRemark.value.length) {
    return message.info('备注信息不能为空')
  }

  const options = { successText: '申请发送成功' }

  const [err] = await fetchApi(
    fetchContactApplyCreate,
    {
      user_id: props.userId,
      remark: applyRemark.value
    },
    options
  )

  if (err) return

  isOpenFrom.value = false
}

const onChangeRemark = async () => {
  const onSuccess = () => {
    editCardPopover.value.setShow(false)
    userInfo.contact_remark.remark = friendRemark.value

    const params = {
      user_id: props.userId,
      remark: friendRemark.value
    }

    talkStore.setRemark(params)
    bus.emit(ContactConst.UpdateRemark, params)
  }

  const [err] = await fetchApi(
    fetchContactEditRemark,
    {
      user_id: props.userId,
      remark: friendRemark.value
    },
    {
      successText: '备注修改成功'
    }
  )

  if (err) return
  onSuccess()
}

const handleSelectGroup = async (value: number) => {
  const [err] = await fetchApi(
    fetchContactChangeGroup,
    {
      user_id: props.userId,
      group_id: value
    },
    {
      successText: '分组修改成功'
    }
  )

  if (err) return
  userInfo.contact_group_id = value
}

const onClose = () => {
  emit('close')
}

onLoadUser()
onLoadUserGroup()
</script>

<template>
  <div class="section">
    <section class="section el-container is-vertical h-full">
      <header 
        class="el-header header" 
        :style="{ background: cardBackground }"
      >
        <im-avatar
          class="avatar"
          :size="60"
          :src="userInfo.avatar"
          :username="userInfo.contact_remark || userInfo.nickname"
          :font-size="30"
        />

        <div class="gender" v-show="userInfo.gender > 0">
          <n-icon v-if="userInfo.gender == 1" :component="Male" color="#ffffff" />
          <n-icon v-if="userInfo.gender == 2" :component="Female" color="#ffffff" />
        </div>

        <div class="close" @click="onClose">
          <close-one theme="outline" size="22" fill="#fff" :strokeWidth="2" />
        </div>

        <div class="nickname text-ellipsis">
          {{ userInfo.contact_remark || userInfo.nickname || '-' }}
        </div>
      </header>

      <main class="el-main main me-scrollbar me-scrollbar-thumb">
        <div class="motto">
          <span style="font-weight: 600">个性签名：</span
          >{{ userInfo.motto || '编辑个签，展示我的独特态度。' }}
        </div>

        <div class="infos">
          <div class="info-item">
            <span class="name">手机</span>
            <span class="text">{{ formatPhone(userInfo.mobile) || '-' }}</span>
          </div>
          <div class="info-item">
            <span class="name">昵称</span>
            <span class="text text-ellipsis">{{ userInfo.nickname || '-' }} </span>
          </div>
          <div class="info-item">
            <span class="name">性别</span>
            <span class="text">{{ genders[userInfo.gender] }}</span>
          </div>
          <div class="info-item" v-if="userInfo.relation === 2">
            <span class="name">备注</span>
            <n-popover trigger="click" placement="top-start" ref="editCardPopover">
              <template #trigger>
                <span class="text edit pointer text-ellipsis">
                  {{ userInfo.contact_remark || '-' }}&nbsp;&nbsp;
                </span>
              </template>

              <template #header> 设置备注 </template>

              <div style="display: flex">
                <n-input
                  type="text"
                  placeholder="请填写备注"
                  :autofocus="true"
                  maxlength="10"
                  v-model:value="friendRemark"
                  @keydown.enter="onChangeRemark"
                />
                <n-button type="primary" text-color="#ffffff" class="mt-l5" @click="onChangeRemark">
                  确定
                </n-button>
              </div>
            </n-popover>
          </div>
          <div class="info-item">
            <span class="name">邮箱</span>
            <span class="text">{{ userInfo.email || '-' }}</span>
          </div>
          <div class="info-item" v-if="userInfo.relation === 2">
            <span class="name">分组</span>
            <n-dropdown
              trigger="click"
              placement="top-start"
              show-arrow
              :options
              @select="handleSelectGroup"
            >
              <span class="text edit pointer">{{ groupName }}</span>
            </n-dropdown>
          </div>
        </div>
      </main>

      <footer
        v-if="[2, 3].includes(userInfo.relation)"
        class="el-footer footer border-top flex-center"
      >
        <n-button
          round
          block
          type="primary"
          text-color="#ffffff"
          @click="onToTalk"
          style="width: 91%"
        >
          <template #icon>
            <n-icon :component="SendOne" />
          </template>
          发送消息
        </n-button>
      </footer>

      <footer v-else-if="userInfo.relation === 1" class="el-footer footer border-top flex-center">
        <template v-if="isOpenFrom">
          <n-input
            type="text"
            placeholder="请填写备注信息"
            v-model:value="applyRemark"
            @keydown.enter="onJoinContact"
          />

          <n-button
            type="primary"
            text-color="#ffffff"
            :disabled="!applyRemark.length"
            class="mt-l5"
            @click="onJoinContact"
          >
            确定
          </n-button>
        </template>
        <template v-else>
          <n-button
            type="primary"
            text-color="#ffffff"
            block
            round
            style="width: 91%"
            @click="isOpenFrom = true"
          >
            添加好友
          </n-button>
        </template>
      </footer>
    </section>
  </div>
</template>

<style lang="less" scoped>
.section {
  position: relative;
  width: 330px;
  max-height: 540px;
  overflow: hidden;
  background-color: var(--im-bg-color);
  border-radius: 10px;
  box-shadow: 0 8px 32px rgba(0, 0, 0, 0.12);

  .header {
    width: 100%;
    height: 160px;
    align-items: center;
    justify-content: center;
    display: flex;
    padding: 20px;
    position: relative;
    overflow: hidden;
    transition: background 0.5s ease;

    // 装饰性圆形图案 - 主题色相关
    &::before {
      width: 180px;
      height: 180px;
      content: '';
      background: linear-gradient(to right, rgba(255,255,255,0.2), rgba(255,255,255,0.05));
      position: absolute;
      z-index: 1;
      border-radius: 50%;
      right: -30%;
      top: -30%;
      animation: float 6s ease-in-out infinite;
    }

    &::after {
      width: 140px;
      height: 140px;
      content: '';
      background: linear-gradient(to left, rgba(255,255,255,0.15), rgba(255,255,255,0.02));
      position: absolute;
      z-index: 1;
      border-radius: 50%;
      left: -20%;
      bottom: -20%;
      animation: float 8s ease-in-out infinite reverse;
    }

    // 额外的装饰元素
    .decoration-circle {
      position: absolute;
      border-radius: 50%;
      background: rgba(255, 255, 255, 0.1);
      z-index: 1;
    }

    .nickname {
      position: absolute;
      bottom: 12px;
      width: 80%;
      height: 30px;
      font-size: 15px;
      line-height: 30px;
      text-align: center;
      color: #ffffff;
      font-weight: 600;
      text-shadow: 0 1px 3px rgba(0, 0, 0, 0.2);
      z-index: 2;
    }

    .gender {
      width: 20px;
      height: 20px;
      position: absolute;
      right: 125px;
      bottom: 45px;
      display: flex;
      align-items: center;
      justify-content: center;
      border-radius: 50%;
      z-index: 2;
    }

    .close {
      position: absolute;
      right: 15px;
      top: 15px;
      z-index: 10;
      width: 28px;
      height: 28px;
      display: flex;
      align-items: center;
      justify-content: center;
      border-radius: 50%;
      background: rgba(255, 255, 255, 0.15);
      transition: all 0.3s ease;
      
      &:hover {
        cursor: pointer;
        background: rgba(255, 255, 255, 0.25);
        transform: scale(1.1);
      }
    }

    .avatar {
      z-index: 2;
      
      :deep(.avatar-container) {
        padding: 3px;
        background: rgba(255, 255, 255, 0.3);
        box-shadow: 0 4px 15px rgba(0, 0, 0, 0.2);
        
        .avatar-inner {
          border: 2px solid #ffffff;
        }
      }
    }
  }

  .main {
    padding: 20px 30px;
    max-height: 300px;
    overflow-y: auto;

    .motto {
      min-height: 26px;
      border-radius: 8px;
      padding: 10px 12px;
      line-height: 22px;
      background: var(--im-bg-secondary, #f3f5f7);
      color: var(--im-text-color);
      font-size: 12px;
      margin-bottom: 20px;
      display: -webkit-box;
      -webkit-box-orient: vertical;
      -webkit-line-clamp: 2;
      position: relative;
      overflow: hidden;
      transition: all 0.3s;
      
      &:hover {
        background: var(--im-hover-bg-color, #e8e8e8);
      }
    }
  }

  .footer {
    height: 60px;
    padding: 0 15px;
  }
}

// 浮动动画
@keyframes float {
  0%, 100% {
    transform: translate(0, 0) scale(1);
  }
  50% {
    transform: translate(-10px, -10px) scale(1.05);
  }
}

.infos {
  .info-item {
    height: 32px;
    width: 100%;
    margin: 4px 0;
    display: flex;
    align-items: center;

    .name {
      width: 45px;
      flex-shrink: 0;
      font-size: 14px;
      color: var(--im-text-secondary);
    }

    .text {
      flex: 1 auto;
      margin-left: 5px;
      font-size: 13px;
      color: var(--im-text-color);
    }
  }
}

// 主题适配
html[theme-mode='huaxia-red'] {
  .section .header {
    .decoration-circle {
      background: rgba(255, 255, 255, 0.12);
    }
  }
}

html[theme-mode='light-gray'] {
  .section .header {
    .decoration-circle {
      background: rgba(255, 255, 255, 0.15);
    }
  }
}

// 响应式适配
@media (max-width: 480px) {
  .section {
    width: 100%;
    max-width: 330px;
  }
}
</style>
