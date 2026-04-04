<script lang="ts" setup>
import QuillEditor, { Delta, Quill } from '@/components/quill-editor'
import { defaultAvatar } from '@/constant/default'
import { EditorConst } from '@/constant/event-bus'
import { useEventBus } from '@/hooks'
import { useEditorDraftStore } from '@/store'
import { getImageInfo } from '@/utils/file'
import {
  ExpandLeft,
  ExpandRight,
  FolderUpload,
  History,
  Voice as IconVoice,
  Pic,
  Ranking,
  SmilingFace,
  SourceCode,
  Send
} from '@icon-park/vue-next'
import Emitter from 'quill/core/emitter.js'
import { computed, markRaw, onMounted, onUnmounted, reactive, ref, watch, nextTick } from 'vue'
import MeEditorCode from './MeEditorCode.vue'
import MeEditorEmoticon from './MeEditorEmoticon.vue'
import MeEditorRecorder from './MeEditorRecorder.vue'
import MeEditorVote from './MeEditorVote.vue'
import { deltaToMessage, deltaToString, isEmptyDelta, onUploadImage } from './util.ts'

const emit = defineEmits(['editor-event', 'trigger-aside'])
const editorDraftStore = useEditorDraftStore()

interface Props {
  showVote: boolean
  showAside?: boolean
  showAsideEment?: boolean
  indexName: string
  members: any[]
  callback: (event: string, data?: any) => Promise<boolean>
}

const {
  showVote = false,
  showAside = false,
  indexName = '',
  members = [],
  callback
} = defineProps<Props>()

const editor = ref(null)
const editorMainRef = ref(null)

// 自适应高度相关
const minEditorHeight = 38 // 最小高度（单行）
const maxEditorHeight = ref(200) // 最大高度
let resizeObserver: ResizeObserver | null = null

// 更新最大高度
const updateMaxHeight = () => {
  const el = editorMainRef.value as HTMLElement | null
  if (!el) return
  const containerHeight = el.clientHeight
  // 最大高度为容器高度的 60%，留出空间给底部工具栏
  const calculatedMax = Math.max(minEditorHeight, Math.floor(containerHeight * 0.6))
  maxEditorHeight.value = calculatedMax
}

// 监听内容变化，自动调整输入框高度
const adjustEditorHeight = () => {
  nextTick(() => {
    const quill = getQuill()
    if (!quill) return

    const root = quill.root
    const scrollHeight = root.scrollHeight
    const editorWrapper = root.closest('.editor-input-wrapper')

    if (editorWrapper) {
      // 内容高度 + padding
      const contentHeight = scrollHeight + 16 // 8px * 2 padding
      const newHeight = Math.min(Math.max(contentHeight, minEditorHeight), maxEditorHeight.value)
      root.style.height = newHeight + 'px'
      root.style.overflowY = contentHeight > maxEditorHeight.value ? 'auto' : 'hidden'
    }
  })
}

const getQuill = () => {
  // @ts-expect-error
  return editor?.value?.getQuill()
}

const getQuillSelectionIndex = () => {
  const quill = getQuill()
  if (!quill) return 0

  return (quill.getSelection() || {}).index || quill.getLength()
}

const isShowEditorVote = ref(false)
const isShowEditorCode = ref(false)
const isShowEditorRecorder = ref(false)
const fileImageRef = ref()
const uploadFileRef = ref()
const emoticonRef = ref()

const editorOption = {
  theme: 'snow',
  placeholder: '按Enter发送 / Shift+Enter 换行',
  formats: ['emoji', 'quote', 'mention', 'image'],
  modules: {
    toolbar: false,

    keyboard: {
      bindings: {
        enter: {
          key: 'Enter',
          // 回车发送消息
          handler: onSendMessage
        }
      }
    },

    mention: {
      allowedChars: /^[\u4e00-\u9fa5]*$/,
      mentionDenotationChars: ['@'],
      positioningStrategy: 'fixed',
      renderItem: (data: any) => {
        const el = document.createElement('div')
        el.className = 'ed-member-item'
        el.innerHTML = `<img src="${data.avatar}" class="avator"/>`
        el.innerHTML += `<span class="nickname">${data.nickname}</span>`
        return el
      },
      source: function (searchTerm: string, render: any) {
        if (!members.length) return render([])

        const items = [
          { id: 0, nickname: '所有人', avatar: defaultAvatar, value: '所有人' },
          ...members.map((item: any) => {
            return {
              id: item.id,
              nickname: item.nickname,
              avatar: item.avatar,
              value: item.nickname
            }
          })
        ]

        render(items.filter((item: any) => item.nickname.toLowerCase().indexOf(searchTerm) !== -1))
      },

      mentionContainerClass: 'ql-mention-list-container me-scrollbar me-scrollbar-thumb'
    },

    uploader: {
      mimetypes: ['image/webp', 'image/gif', 'image/png', 'image/jpg', 'image/jpeg'],
      handler(range: any, files: File[]) {
        // @ts-expect-error
        const quill = this.quill

        if (!quill.scroll.query('image')) return

        const promises = files.map((file) => {
          return onUploadImage(file)
        })

        Promise.all(promises).then((images) => {
          const update = images.reduce((delta: any, image) => {
            return delta.insert({ image })
          }, new Delta().retain(range.index).delete(range.length))

          quill.updateContents(update, Emitter.sources.USER)
          quill.setSelection(range.index + images.length, Emitter.sources.SILENT)
        })
      }
    }
  }
}

// 输入框下方的功能菜单
const footerNavs = reactive([
  {
    title: '图片',
    icon: markRaw(Pic),
    show: true,
    click: () => {
      fileImageRef.value.click()
    }
  },
  {
    title: '附件',
    icon: markRaw(FolderUpload),
    show: true,
    click: () => {
      uploadFileRef.value.click()
    }
  },
  {
    title: '代码',
    icon: markRaw(SourceCode),
    show: true,
    click: () => {
      isShowEditorCode.value = true
    }
  },
  {
    title: '语音消息',
    icon: markRaw(IconVoice),
    show: true,
    click: () => {
      isShowEditorRecorder.value = true
    }
  },
  {
    title: '群投票',
    icon: markRaw(Ranking),
    show: computed(() => showVote),
    click: () => {
      isShowEditorVote.value = true
    }
  },
  {
    title: '历史记录',
    icon: markRaw(History),
    show: true,
    click: () => {
      callback('history_event')
    }
  }
])

// <expand-right theme="outline" size="24" fill="#333" :strokeWidth="2"/>

async function onVoteEvent(data: any) {
  const ok = await callback('vote_event', data)
  ok && (isShowEditorVote.value = false)
}

async function onEmoticonEvent(data: any) {
  emoticonRef.value.setShow(false)

  if (data.type == 1) {
    const quill = getQuill()
    let index = getQuillSelectionIndex()

    if (index == 1 && quill.getLength() == 1 && quill.getText(0, 1) == '\n') {
      quill.deleteText(0, 1)
      index = 0
    }

    if (data.img) {
      quill.insertEmbed(index, 'emoji', {
        alt: data.value,
        src: data.img,
        width: '24px',
        height: '24px'
      })
    } else {
      quill.insertText(index, data.value)
    }

    quill.setSelection(index + 1, 0, 'user')
  } else {
    await callback('emoticon_event', data.value)
  }
}

async function onCodeEvent(data: any) {
  const ok = await callback('code_event', data)
  ok && (isShowEditorCode.value = false)
}

async function onUploadFile(e: any) {
  if (!e.target.files) return

  const file = e.target.files[0]

  e.target.value = null

  if (file.type.indexOf('image/') === 0) {
    const quill = getQuill()
    let index = getQuillSelectionIndex()

    if (index == 1 && quill.getLength() == 1 && quill.getText(0, 1) == '\n') {
      quill.deleteText(0, 1)
      index = 0
    }

    let src = await onUploadImage(file)
    if (src) {
      quill.insertEmbed(index, 'image', src)
      quill.setSelection(index + 1)
    }

    return
  }

  if (file.type.indexOf('video/') === 0) {
    await callback('video_event', file)
  } else {
    await callback('file_event', file)
  }
}

async function onRecorderEvent(file: any) {
  const ok = await callback('file_event', file)
  ok && (isShowEditorRecorder.value = false)
}
async function onSendMessage() {
  let delta = getQuill().getContents()
  let data = deltaToMessage(delta)

  if (data.items.length === 0) return

  if (data.msgType == 1) {
    if (data.items[0].content.length > 1024) {
      return window['$message'].info('发送内容超长，请分条发送')
    }

    const ok = await callback('text_event', data)
    ok && getQuill().setContents([], Quill.sources.USER)
    return
  }

  if (data.msgType == 3) {
    const ok = await callback('image_event', {
      ...getImageInfo(data.items[0].content),
      url: data.items[0].content,
      size: 10000
    })

    ok && getQuill().setContents([], Quill.sources.USER)
    return
  }

  if (data.msgType == 12) {
    const ok = await callback('mixed_event', data)
    ok && getQuill().setContents([], Quill.sources.USER)
    return
  }
}

function onEditorChange() {
  const delta: any = getQuill().getContents()

  const text = deltaToString(delta)

  if (!isEmptyDelta(delta)) {
    editorDraftStore.items[indexName || ''] = JSON.stringify({
      text: text,
      ops: delta.ops
    })
  } else {
    // 删除 editorDraftStore.items 下的元素
    delete editorDraftStore.items[indexName || '']
  }

  callback('input_event', text)

  // 自动调整输入框高度
  adjustEditorHeight()
}

function loadEditorDraftText() {
  // 这里延迟处理，不然会有问题
  setTimeout(() => {
    hideMentionDom()

    const quill = getQuill()

    if (!quill) return

    // 从缓存中加载编辑器草稿
    let draft = editorDraftStore.items[indexName || '']
    if (draft) {
      quill.setContents(JSON.parse(draft)?.ops || [])
    } else {
      quill.setContents([])
    }

    quill.setSelection(getQuillSelectionIndex(), 0, 'user')
  }, 10)
}

function onSubscribeMention(data: { id: number; value: string }) {
  const quill = getQuill()

  const mention = quill.getModule('mention')

  mention.mentionCharPos = quill.getSelection()?.index ?? quill.getLength()

  mention.insertItem({ id: data?.id, denotationChar: '@', value: data.value }, false)
}

function onSubscribeQuote(data: any) {
  const delta = getQuill().getContents()
  if (delta.ops?.some((item: any) => item.insert.quote)) {
    return
  }

  const quill = getQuill()
  const index = getQuillSelectionIndex()

  quill.insertEmbed(0, 'quote', data)
  quill.setSelection(index + 1, 0, 'user')
}

function hideMentionDom() {
  let el = document.querySelector('.ql-mention-list-container')
  el && el.remove()
}

watch(() => indexName, loadEditorDraftText, { immediate: true })

onMounted(() => {
  loadEditorDraftText()

  // 设置 ResizeObserver 监听容器尺寸变化
  if (editorMainRef.value) {
    resizeObserver = new ResizeObserver(() => {
      updateMaxHeight()
      adjustEditorHeight()
    })
    resizeObserver.observe(editorMainRef.value)
    updateMaxHeight()
  }
})

onUnmounted(() => {
  hideMentionDom()
  // 清理 ResizeObserver
  if (resizeObserver) {
    resizeObserver.disconnect()
    resizeObserver = null
  }
})

useEventBus([
  { name: EditorConst.Mention, event: onSubscribeMention },
  { name: EditorConst.Quote, event: onSubscribeQuote }
])
</script>

<template>
  <section class="el-container is-vertical editor">
    <form enctype="multipart/form-data" style="display: none">
      <input type="file" ref="fileImageRef" accept="image/*" @change="onUploadFile" />
      <input type="file" ref="uploadFileRef" @change="onUploadFile" />
    </form>

    <div class="editor-input-wrapper" ref="editorMainRef">
      <QuillEditor
        ref="editor"
        :options="editorOption"
        @change="onEditorChange"
        class="editor-quill"
      />
    </div>

    <!-- 输入框下方工具栏 -->
    <footer class="el-footer footer-toolbar">
      <div class="footer-navs">
        <n-popover
          placement="top-start"
          trigger="click"
          raw
          :width="300"
          ref="emoticonRef"
          style="
            width: 500px;
            height: 250px;
            border-radius: 10px;
            overflow: hidden;
            box-shadow: none;
            border: 1px solid var(--border-color);
          "
        >
          <template #trigger>
            <div class="footer-nav-item">
              <n-icon size="18" class="icon" :component="SmilingFace" />
            </div>
          </template>
          <MeEditorEmoticon @on-select="onEmoticonEvent" />
        </n-popover>

        <div
          class="footer-nav-item"
          v-for="nav in footerNavs"
          :key="nav.title"
          v-show="nav.show"
          @click="nav.click"
        >
          <n-icon size="18" class="icon" :component="nav.icon" />
        </div>
      </div>
      <div class="send-btn" @click="onSendMessage">
        <n-icon size="18" :component="Send" />
        <span>发送</span>
      </div>
    </footer>
  </section>

  <MeEditorVote v-if="isShowEditorVote" @close="isShowEditorVote = false" @submit="onVoteEvent" />

  <MeEditorCode
    v-if="isShowEditorCode"
    @on-submit="onCodeEvent"
    @close="isShowEditorCode = false"
  />

  <MeEditorRecorder
    v-if="isShowEditorRecorder"
    @on-submit="onRecorderEvent"
    @close="isShowEditorRecorder = false"
  />
</template>

<style lang="less" scoped>
.editor {
  --tip-bg-color: rgb(241 241 241 / 90%);
  --send-btn-bg: var(--im-primary-color, #5B6B79);
  --send-btn-hover: var(--im-primary-hover, #6B7B89);

  height: 100%;
  display: flex;
  flex-direction: column;
  padding: 12px;
  padding-bottom: 0;
  box-sizing: border-box;

  .editor-input-wrapper {
    width: 100%;
    flex: 1;
    min-height: 0;
    margin: 0 0 12px 0;
    border-radius: 8px;
    border: 1px solid #d9d9d9;
    background: #ffffff;
    overflow: hidden;
    transition: border-color 0.2s, box-shadow 0.2s;
    display: flex;
    flex-direction: column;

    &:hover,
    &:focus-within {
      border-color: var(--im-primary-color);
      box-shadow: 0 0 0 2px rgba(91, 107, 121, 0.1);
    }

    :deep(.quill-editor) {
      flex: 1;
      display: flex;
      flex-direction: column;
      min-height: 0;

      > section {
        flex: 1;
        display: flex;
        flex-direction: column;
        min-height: 0;
      }
    }
  }

  .footer-toolbar {
    flex-shrink: 0;
    height: 42px;
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 0 12px;
    background: var(--im-bg-color);

    .footer-navs {
      display: flex;
      align-items: center;
      gap: 4px;

      .footer-nav-item {
        display: flex;
        align-items: center;
        justify-content: center;
        width: 32px;
        height: 32px;
        border-radius: 6px;
        cursor: pointer;
        transition: all 0.2s;
        color: var(--im-text-secondary);

        &:hover {
          background: var(--im-bg-hover);
          color: var(--im-primary-color);
        }

        .icon {
          transition: color 0.2s;
        }
      }
    }

    .send-btn {
      display: flex;
      align-items: center;
      gap: 6px;
      padding: 6px 16px;
      border-radius: 6px;
      background: var(--send-btn-bg);
      color: #ffffff;
      font-size: 13px;
      font-weight: 500;
      cursor: pointer;
      transition: all 0.2s;

      &:hover {
        background: var(--send-btn-hover);
        transform: translateY(-1px);
        box-shadow: 0 2px 8px rgba(0, 0, 0, 0.15);
      }

      &:active {
        transform: translateY(0);
        box-shadow: none;
      }
    }
  }
}

html[theme-mode='dark'] {
  .editor {
    --tip-bg-color: #48484d;
  }
}
</style>

<style lang="less">
.ql-container.ql-snow {
  border: unset;
  flex: 1;
  min-height: 0;
  display: flex;
  flex-direction: column;
}

.ql-editor {
  flex: 1;
  padding: 8px;
  border: unset;
  background: #ffffff;
  border-radius: 8px;
  color: #333;
  box-sizing: border-box;
  min-height: 0;
  overflow-y: auto;

  &::-webkit-scrollbar {
    width: 3px;
    height: 3px;
    background-color: unset;
  }

  &::-webkit-scrollbar-thumb {
    border-radius: 3px;
    background-color: transparent;
  }

  &:hover {
    &::-webkit-scrollbar-thumb {
      background-color: var(--im-scrollbar-thumb);
    }
  }
}

.ql-editor.ql-blank::before {
  font-family:
    PingFang SC,
    Microsoft YaHei,
    'Alibaba PuHuiTi 2.0 45' !important;
  left: 8px;
}

.ql-snow .ql-editor img {
  max-width: 100px;
  border-radius: 3px;
  background-color: #48484d;
  margin: 0px 2px;
}

.ed-emoji {
  background-color: unset !important;
}

.ql-editor.ql-blank::before {
  font-style: unset;
  color: #b8b3b3;
}

.quote-card-content {
  display: flex;
  background-color: #f6f6f6;
  flex-direction: column;
  padding: 5px;
  margin-bottom: 5px;
  cursor: pointer;
  user-select: none;

  .quote-card-title {
    height: 22px;
    line-height: 22px;
    font-size: 12px;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
    display: flex;
    justify-content: space-between;

    .quote-card-remove {
      margin-right: 5px;
      font-size: 20px;
      display: flex;
      align-items: center;
      justify-content: center;
      width: 20px;
      height: 20px;
      transition: all 0.3s;
    }
  }

  &:hover .quote-card-title .quote-card-remove {
    font-size: 30px;
  }

  .quote-card-meta {
    margin-top: 4px;
    font-size: 12px;
    line-height: 20px;
    color: #999;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }
}

html[theme-mode='dark'] {
  .ql-editor.ql-blank::before {
    color: #57575a;
  }

  .ql-editor {
    background: #2c2c32;
    color: #e0e0e0;
  }

  .editor-input-wrapper {
    border-color: #444;
    background: #2c2c32;

    &:hover,
    &:focus-within {
      border-color: var(--im-primary-color);
    }
  }

  .quote-card-content {
    background-color: var(--im-message-bg-color);
  }
}
</style>
