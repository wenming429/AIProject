<script lang="ts" setup>
import { useUserStore, useTalkStore } from '@/store'
import { Peoples, ChartGraph, Right, DownOne, Male, Female, Search } from '@icon-park/vue-next'
import { ref, computed, onMounted } from 'vue'
import { fetchOrganizeDepartmentList, fetchOrganizePersonnelList } from '@/apis/api'
import { fetchApi } from '@/apis/request'
import { useRouter } from 'vue-router'
import { useInject } from '@/hooks'

const userStore = useUserStore()
const talkStore = useTalkStore()
const router = useRouter()
const { toShowUserInfo, message } = useInject()

// 当前激活的Tab: 'group' = 我的群聊, 'organize' = 组织架构
const activeTab = ref('organize')

// 组织架构相关数据
const deptTree = ref<any[]>([])
const personnelList = ref<any[]>([])
const expandedKeys = ref<number[]>([])
const keywords = ref('')

// 切换Tab
function switchTab(tab: string) {
  activeTab.value = tab
}

// 构建部门树
function buildTree(list: any[]): any[] {
  const map: Record<number, any> = {}
  list.forEach(item => {
    map[item.dept_id] = { ...item, children: [] }
  })
  
  const tree: any[] = []
  list.forEach(item => {
    if (item.parent_id && map[item.parent_id]) {
      map[item.parent_id].children.push(map[item.dept_id])
    } else {
      tree.push(map[item.dept_id])
    }
  })
  
  return tree
}

// 加载组织架构数据
async function loadOrganizeData() {
  const [deptErr, deptData] = await fetchApi(fetchOrganizeDepartmentList, {})
  if (!deptErr) {
    const list = deptData.items || []
    deptTree.value = buildTree(list)
    // 默认展开第一级
    if (deptTree.value.length > 0) {
      expandedKeys.value = deptTree.value.map(d => d.dept_id)
    }
  }
  
  const [userErr, userData] = await fetchApi(fetchOrganizePersonnelList, {})
  if (!userErr) {
    const users = userData.items || []
    users.forEach((item: any) => {
      item.position_items.sort((a: any, b: any) => a.sort - b.sort)
    })
    personnelList.value = users
  }
}

// 切换展开/收起
function toggleExpand(dept: any, e: Event) {
  e.stopPropagation()
  const index = expandedKeys.value.indexOf(dept.dept_id)
  if (index > -1) {
    expandedKeys.value.splice(index, 1)
  } else {
    expandedKeys.value.push(dept.dept_id)
  }
}

// 获取部门下的人员
function getDeptUsers(deptId: number): any[] {
  return personnelList.value.filter(p => p.dept_item?.dept_id === deptId)
}

// 发送消息
function onToTalk(item: any, e: Event) {
  e.stopPropagation()
  if (userStore.uid != item.user_id) {
    talkStore.toTalk(1, item.user_id, router)
  } else {
    message.info('禁止给自己发送消息!')
  }
}

// 查看用户信息
function onShowUserInfo(item: any) {
  toShowUserInfo(item.user_id)
}

// 检查部门是否展开
function isExpanded(deptId: number): boolean {
  return expandedKeys.value.includes(deptId)
}

onMounted(() => {
  loadOrganizeData()
})
</script>

<template>
  <div class="embedded-contact">
    <!-- 顶部Tab切换 -->
    <header class="contact-tabs">
      <div 
        class="tab-item" 
        :class="{ active: activeTab === 'group' }"
        @click="switchTab('group')"
      >
        <n-icon :component="Peoples" size="16" />
        <span>我的群聊</span>
      </div>
      <div 
        class="tab-item" 
        :class="{ active: activeTab === 'organize' }"
        @click="switchTab('organize')"
      >
        <n-icon :component="ChartGraph" size="16" />
        <span>组织架构</span>
      </div>
    </header>

    <!-- 内容区 -->
    <div class="contact-body">
      <!-- 我的群聊 -->
      <div v-if="activeTab === 'group'" class="tab-content">
        <GroupList />
      </div>
      
      <!-- 组织架构 -->
      <div v-else-if="activeTab === 'organize'" class="tab-content organize-content">
        <!-- 搜索栏 -->
        <div class="organize-search">
          <n-input
            v-model:value="keywords"
            placeholder="搜索成员"
            clearable
            size="small"
          >
            <template #prefix>
              <n-icon :component="Search" />
            </template>
          </n-input>
        </div>
        
        <!-- 组织树 -->
        <n-scrollbar class="organize-scroll">
          <div class="organize-tree">
            <!-- 递归组件渲染部门树 -->
            <OrganizeTreeNode
              v-for="dept in deptTree"
              :key="dept.dept_id"
              :dept="dept"
              :expanded-keys="expandedKeys"
              :personnel-list="personnelList"
              @toggle-expand="toggleExpand"
              @to-talk="onToTalk"
              @show-user-info="onShowUserInfo"
            />
          </div>
        </n-scrollbar>
      </div>
    </div>
  </div>
</template>

<script lang="ts">
import GroupList from '@/views/contact/group.vue'
import OrganizeTreeNode from './OrganizeTreeNode.vue'

export default {
  components: {
    GroupList,
    OrganizeTreeNode
  }
}
</script>

<style lang="less" scoped>
.embedded-contact {
  height: 100%;
  display: flex;
  flex-direction: column;
  background: #f5f5f5;

  // 顶部Tab切换
  .contact-tabs {
    display: flex;
    background: #fff;
    border-bottom: 1px solid #e8e8e8;
    flex-shrink: 0;

    .tab-item {
      flex: 1;
      display: flex;
      align-items: center;
      justify-content: center;
      gap: 6px;
      padding: 12px 0;
      cursor: pointer;
      font-size: 14px;
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

  // 内容区
  .contact-body {
    flex: 1;
    overflow: hidden;

    .tab-content {
      height: 100%;

      &.organize-content {
        display: flex;
        flex-direction: column;

        .organize-search {
          padding: 10px 12px;
          background: #fff;
          border-bottom: 1px solid #f0f0f0;
          flex-shrink: 0;
        }

        .organize-scroll {
          flex: 1;
          background: #fff;

          .organize-tree {
            padding: 8px 0;
          }
        }
      }
    }
  }
}
</style>
