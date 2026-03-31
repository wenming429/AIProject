<script lang="ts" setup>
import FloatingChat from '@/components/chat/FloatingChat.vue'

// 嵌入页面 - 只显示悬浮聊天窗口
</script>

<template>
  <div class="embed-container">
    <!-- 悬浮聊天窗口（包含完整功能菜单） -->
    <FloatingChat />
  </div>
</template>

<style lang="less" scoped>
.embed-container {
  width: 0;
  height: 0;
  overflow: hidden;
}
</style>
