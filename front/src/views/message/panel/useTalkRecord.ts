import { fetchMessageRecords } from '@/apis/api'
import { useDialogueStore } from '@/store'
import { ITalkRecord } from '@/types/chat'
import { safeParseJson } from '@/utils/common'
import { getMediaUrl } from '@/utils/media'

// 消息类型常量
const CHAT_MSG_TYPE_IMAGE = 2 // 图片
const CHAT_MSG_TYPE_AUDIO = 3 // 语音
const CHAT_MSG_TYPE_VIDEO = 4 // 视频
const CHAT_MSG_TYPE_MIXED = 9 // 图文消息

export function useTalkRecord() {
  const dialogueStore = useDialogueStore()

  const records = computed((): ITalkRecord[] => dialogueStore.records)

  let cursor = 0

  // 处理消息记录中的媒体 URL
  function processMediaUrls(item: any): any {
    if (!item.extra) return item

    // 图片消息
    if (item.msg_type === CHAT_MSG_TYPE_IMAGE && item.extra.url) {
      item.extra.url = getMediaUrl(item.extra.url)
    }

    // 语音消息
    if (item.msg_type === CHAT_MSG_TYPE_AUDIO && item.extra.url) {
      item.extra.url = getMediaUrl(item.extra.url)
    }

    // 视频消息
    if (item.msg_type === CHAT_MSG_TYPE_VIDEO) {
      if (item.extra.url) {
        item.extra.url = getMediaUrl(item.extra.url)
      }
      if (item.extra.cover) {
        item.extra.cover = getMediaUrl(item.extra.cover)
      }
    }

    // 图文消息
    if (item.msg_type === CHAT_MSG_TYPE_MIXED && item.extra.items) {
      item.extra.items.forEach((i: any) => {
        // 如果内容是 URL（图片等）
        if (i.content && (i.content.startsWith('/public/') || i.content.startsWith('/media/'))) {
          i.content = getMediaUrl(i.content)
        }
      })
    }

    return item
  }

  // 加载数据列表
  const loadChatRecord = async (): Promise<boolean> => {
    const { target: talk } = dialogueStore

    const request = {
      talk_mode: talk.talk_mode,
      to_from_id: talk.to_from_id,
      cursor: cursor,
      limit: 30
    }

    try {
      console.log('Loading talk records with request:', request)
      const data = await fetchMessageRecords(request)

      if (request.talk_mode !== talk.talk_mode || request.to_from_id !== talk.to_from_id) {
        console.error('Talk mode or to_from_id changed')
        throw new Error('Talk mode or to_from_id changed')
      }

      if (request.cursor === 0) {
        dialogueStore.clearDialogueRecord()
      }

      const list = data.items.map((item: any) => {
        item.extra = safeParseJson(item.extra || '{}')
        item.quote = safeParseJson(item.quote || '{}')
        item.status = 1
        // 处理媒体 URL
        item = processMediaUrls(item)
        return item
      })

      dialogueStore.unshiftDialogueRecord(list.reverse())
      cursor = data.cursor

      return data.items.length < request.limit ? false : true
    } catch (error) {
      console.error('Error loading talk records:', error)
      throw error
    }
  }

  // 重置对话记录
  const resetTalkRecord = (): void => {
    cursor = 0
    dialogueStore.clearDialogueRecord()
  }

  return { records, loadChatRecord, dialogueStore, resetTalkRecord }
}
