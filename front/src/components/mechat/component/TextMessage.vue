<script lang="ts" setup>
import { textReplaceEmoji } from '@/utils/emojis'
import { textReplaceLink, textReplaceMention } from '@/utils/string'
import { useThemeMode } from '@/hooks'

const { currentTheme } = useThemeMode()

const props = defineProps<{
  content: string
  role: string
}>()

let textContent = props.content || ''

textContent = textReplaceLink(textContent)
textContent = textReplaceEmoji(textContent)
textContent = textReplaceMention(textContent)
</script>

<template>
  <div
    class="immsg-text"
    :class="{
      user: role === 'user'
    }"
    :style="{
      '--bubble-left-bg': currentTheme.bubbleLeftBg,
      '--bubble-left-text': currentTheme.bubbleLeftText,
      '--bubble-right-bg': currentTheme.bubbleRightBg,
      '--bubble-right-text': currentTheme.bubbleRightText,
      '--bubble-link': currentTheme.bubbleLink
    }"
  >
    <pre v-html="textContent" />
  </div>
</template>

<style lang="less" scoped>
.immsg-text {
  min-width: 30px;
  min-height: 30px;
  padding: 8px 12px;
  border-radius: 8px;
  background: var(--bubble-left-bg);
  color: var(--bubble-left-text);
  transition: all 0.3s;

  &.user {
    background: var(--bubble-right-bg);
    color: var(--bubble-right-text);

    pre {
      :deep(a) {
        color: rgba(255, 255, 255, 0.9);
        text-decoration: underline;
      }
    }
  }

  pre {
    white-space: pre-wrap;
    overflow: hidden;
    word-break: break-word;
    word-wrap: break-word;
    font-size: 14px;
    font-family:
      system,
      -apple-system,
      BlinkMacSystemFont,
      PingFang SC,
      Segoe UI,
      Microsoft YaHei,
      wenquanyi micro hei,
      Hiragino Sans GB,
      Hiragino Sans GB W3,
      Roboto,
      Oxygen,
      Ubuntu,
      Cantarell,
      Fira Sans,
      Droid Sans,
      Helvetica Neue,
      Helvetica,
      Arial,
      sans-serif;
    line-height: 1.6;
    margin: 0;

    :deep(.emoji) {
      vertical-align: text-bottom;
      margin: 0 3px;
    }

    :deep(a) {
      color: var(--bubble-link);
      text-decoration: revert;
    }
  }
}
</style>
