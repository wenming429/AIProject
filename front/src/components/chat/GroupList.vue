<script lang="ts" setup>
import GroupLaunch from '@/components/group/GroupLaunch.vue'
import GroupPanel from '@/components/group/GroupPanel.vue'
import { useTalkStore, useUserStore } from '@/store'
import { Plus, Search, Peoples } from '@icon-park/vue-next'
import GroupCard from '@/views/contact/inner/GroupCard.vue'
import { fetchGroupList } from '@/apis/api'
import { fetchApi } from '@/apis/request'
import { useRouter } from 'vue-router'

const router = useRouter()
const userStore = useUserStore()
const talkStore = useTalkStore()
const isShowCreateGroupBox = ref(false)
const keywords = ref('')
const items = ref<any[]>([])

const params = reactive({
  isShow: false,
  group_id: 0
})

const tabIndex = ref('all')

const uid = userStore.uid

const filterCreator = computed(() => {
  return items.value.filter((item: any) => item.creator_id == uid)
})

const filter = computed((): any[] => {
  return items.value.filter((item: any) => {
    if (tabIndex.value == 'create' && item.creator_id != uid) {
      return false
    }

    if (tabIndex.value == 'join' && item.creator_id == uid) {
      return false
    }

    return item.group_name.toLowerCase().indexOf(keywords.value.toLowerCase()) != -1
  })
})

const onLoadData = async () => {
  const [err, data] = await fetchApi(fetchGroupList, {})

  if (!err) {
    items.value = data.items || []
  }
}

const onShowGroup = (item: any) => {
  params.isShow = true
  params.group_id = item.group_id
}

const onToTalk = (item: any) => {
  talkStore.toTalk(2, item.group_id, router)
}

const onGroupCallBack = () => {
  isShowCreateGroupBox.value = false
  onLoadData()
  talkStore.loadTalkList()
}

onMounted(() => {
  onLoadData()
})
</script>

<template>
  <div class="group-list-container">
    <!-- 头部区域 - 与组织架构保持一致 -->
    <header class="group-header">
      <div class="header-title">
        <n-icon :component="Peoples" size="16" />
        <span>我的群聊</span>
        <span class="group-count">({{ items.length }})</span>
      </div>
      <n-input
        v-model:value.trim="keywords"
        placeholder="搜索群聊"
        clearable
        size="small"
        class="search-input"
      >
        <template #prefix>
          <n-icon :component="Search" />
        </template>
      </n-input>
      <n-button type="primary" size="small" @click="isShowCreateGroupBox = true">
        <template #icon>
          <n-icon :component="Plus" />
        </template>
        创建群聊
      </n-button>
    </header>

    <!-- Tab 切换 -->
    <div class="group-tabs">
      <div 
        class="tab-item" 
        :class="{ active: tabIndex === 'all' }"
        @click="tabIndex = 'all'"
      >
        全部({{ items.length }})
      </div>
      <div 
        class="tab-item" 
        :class="{ active: tabIndex === 'create' }"
        @click="tabIndex = 'create'"
      >
        我创建的({{ filterCreator.length }})
      </div>
      <div 
        class="tab-item" 
        :class="{ active: tabIndex === 'join' }"
        @click="tabIndex = 'join'"
      >
        我加入的({{ items.length - filterCreator.length }})
      </div>
    </div>

    <!-- 群聊列表 -->
    <main class="group-main">
      <n-scrollbar v-if="filter.length > 0" class="group-scroll">
        <div class="group-cards">
          <div
            v-for="item in filter"
            :key="item.group_id"
            class="group-card"
            @click="onShowGroup(item)"
          >
            <div class="group-avatar">
              <im-avatar :src="item.avatar" :size="44" :username="item.group_name" />
            </div>
            <div class="group-info">
              <div class="group-name">{{ item.group_name }}</div>
              <div class="group-profile">{{ item.profile || '暂无群简介' }}</div>
            </div>
            <div class="group-actions">
              <n-button 
                type="primary" 
                size="small"
                @click.stop="onToTalk(item)"
              >
                进入群聊
              </n-button>
            </div>
          </div>
        </div>
      </n-scrollbar>
      <div v-else class="empty-state">
        <n-empty description="暂无相关数据" size="small" />
      </div>
    </main>
  </div>

  <GroupLaunch
    :group-id="0"
    v-if="isShowCreateGroupBox"
    @close="isShowCreateGroupBox = false"
    @on-submit="onGroupCallBack"
  />

  <n-drawer
    v-model:show="params.isShow"
    :width="400"
    placement="right"
    :trap-focus="false"
    :block-scroll="false"
    to="#drawer-target"
    show-mask="transparent"
  >
    <GroupPanel
      :group-id="params.group_id"
      @close="params.isShow = false"
      @to-talk="talkStore.toTalk(2, params.group_id, router)"
    />
  </n-drawer>
</template>

<style lang="less" scoped>
.group-list-container {
  height: 100%;
  display: flex;
  flex-direction: column;
  background: #f5f5f5;

  // 头部区域 - 与组织架构面板头部保持一致
  .group-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 12px 16px;
    background: #fff;
    border-bottom: 1px solid #f0f0f0;
    flex-shrink: 0;
    gap: 12px;

    .header-title {
      display: flex;
      align-items: center;
      gap: 8px;
      font-size: 15px;
      font-weight: 500;
      color: #333;
      white-space: nowrap;

      .group-count {
        font-size: 13px;
        color: #999;
        font-weight: normal;
      }
    }

    .search-input {
      width: 240px;
    }
  }

  // Tab 切换
  .group-tabs {
    display: flex;
    background: #fff;
    border-bottom: 1px solid #e8e8e8;
    flex-shrink: 0;

    .tab-item {
      flex: 1;
      display: flex;
      align-items: center;
      justify-content: center;
      padding: 10px 0;
      cursor: pointer;
      font-size: 13px;
      color: #666;
      transition: all 0.2s;
      position: relative;

      &:hover {
        color: #333;
        background: #f5f5f5;
      }

      &.active {
        color: #8B0000;
        font-weight: 500;

        &::after {
          content: '';
          position: absolute;
          bottom: 0;
          left: 20%;
          right: 20%;
          height: 2px;
          background: #8B0000;
          border-radius: 2px;
        }
      }
    }
  }

  // 主内容区
  .group-main {
    flex: 1;
    overflow: hidden;

    .group-scroll {
      height: 100%;
      background: #f5f5f5;

      .group-cards {
        padding: 12px;

        .group-card {
          display: flex;
          align-items: center;
          padding: 12px 16px;
          background: #fff;
          border-radius: 8px;
          margin-bottom: 10px;
          transition: all 0.2s;
          border: 1px solid transparent;
          cursor: pointer;

          &:hover {
            border-color: #1890ff;
            box-shadow: 0 2px 8px rgba(24, 144, 255, 0.1);

            .group-actions {
              opacity: 1;
            }
          }

          .group-avatar {
            flex-shrink: 0;
            margin-right: 12px;
          }

          .group-info {
            flex: 1;
            min-width: 0;

            .group-name {
              font-size: 15px;
              font-weight: 500;
              color: #333;
              margin-bottom: 4px;
              overflow: hidden;
              text-overflow: ellipsis;
              white-space: nowrap;
            }

            .group-profile {
              font-size: 12px;
              color: #999;
              overflow: hidden;
              text-overflow: ellipsis;
              white-space: nowrap;
            }
          }

          .group-actions {
            flex-shrink: 0;
            opacity: 0;
            transition: opacity 0.2s;
          }
        }
      }
    }

    .empty-state {
      height: 300px;
      display: flex;
      align-items: center;
      justify-content: center;
    }
  }
}
</style>
