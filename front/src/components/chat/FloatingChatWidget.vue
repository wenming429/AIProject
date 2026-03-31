<script lang="ts" setup>
import { useUserStore } from '@/store'
import FloatingChat from './FloatingChat.vue'
import { isLogin } from '@/utils/auth.ts'

const userStore = useUserStore()

// 组件显示状态
const isVisible = ref(false)

// 初始化检查
onMounted(() => {
  // 如果已登录，显示悬浮球
  if (isLogin()) {
    isVisible.value = true
  }
})

// 监听登录状态
watch(
  () => userStore.uid,
  (uid) => {
    isVisible.value = !!uid
  },
  { immediate: true }
)

// 提供全局方法
defineExpose({
  open: () => {
    isVisible.value = true
  },
  close: () => {
    isVisible.value = false
  }
})
</script>

<template>
  <FloatingChat v-if="isVisible" />
</template>

<style lang="less" scoped>
/* 组件本身不需要样式，样式由 FloatingChat 提供 */
</style>
