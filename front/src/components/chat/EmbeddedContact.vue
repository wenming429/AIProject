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
const selectedDeptId = ref<number | null>(null)
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
    // 默认展开第一级并选中第一个
    if (deptTree.value.length > 0) {
      expandedKeys.value = deptTree.value.map(d => d.dept_id)
      selectedDeptId.value = deptTree.value[0].dept_id
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

// 选择部门
function selectDept(dept: any) {
  selectedDeptId.value = dept.dept_id
  // 自动展开选中的部门
  if (!expandedKeys.value.includes(dept.dept_id)) {
    expandedKeys.value.push(dept.dept_id)
  }
}

// 获取当前选中部门的信息
const selectedDept = computed(() => {
  const findDept = (tree: any[]): any => {
    for (const dept of tree) {
      if (dept.dept_id === selectedDeptId.value) return dept
      if (dept.children?.length) {
        const found = findDept(dept.children)
        if (found) return found
      }
    }
    return null
  }
  return findDept(deptTree.value)
})

// 获取选中部门及子部门的所有人员
const currentDeptUsers = computed(() => {
  if (!selectedDeptId.value) return []
  
  // 获取选中部门及其所有子部门的ID
  const getAllDeptIds = (dept: any): number[] => {
    const ids = [dept.dept_id]
    if (dept.children?.length) {
      dept.children.forEach((child: any) => {
        ids.push(...getAllDeptIds(child))
      })
    }
    return ids
  }
  
  const deptIds = selectedDept.value ? getAllDeptIds(selectedDept.value) : [selectedDeptId.value]
  
  // 过滤人员并搜索
  let users = personnelList.value.filter(p => deptIds.includes(p.dept_item?.dept_id))
  
  if (keywords.value) {
    const kw = keywords.value.toLowerCase()
    users = users.filter(p => 
      p.nickname?.toLowerCase().includes(kw) ||
      p.position_items?.some((pos: any) => pos.name.toLowerCase().includes(kw))
    )
  }
  
  return users.sort((a, b) => a.nickname.localeCompare(b.nickname, 'zh-CN'))
})

// 获取部门下的人员数量（包含子部门）
function getDeptUserCount(dept: any): number {
  const getAllDeptIds = (d: any): number[] => {
    const ids = [d.dept_id]
    if (d.children?.length) {
      d.children.forEach((child: any) => {
        ids.push(...getAllDeptIds(child))
      })
    }
    return ids
  }
  
  const deptIds = getAllDeptIds(dept)
  return personnelList.value.filter(p => deptIds.includes(p.dept_item?.dept_id)).length
}

// 发送消息
function onToTalk(item: any) {
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

// 分割条拖动
const sidebarWidth = ref(180)
const isDragging = ref(false)
const startX = ref(0)
const startWidth = ref(180)

function onDragStart(e: MouseEvent) {
  isDragging.value = true
  startX.value = e.clientX
  startWidth.value = sidebarWidth.value
  document.addEventListener('mousemove', onDrag)
  document.addEventListener('mouseup', onDragEnd)
  document.body.style.cursor = 'col-resize'
  document.body.style.userSelect = 'none'
}

function onDrag(e: MouseEvent) {
  if (!isDragging.value) return
  const delta = e.clientX - startX.value
  const newWidth = startWidth.value + delta
  sidebarWidth.value = Math.max(120, Math.min(400, newWidth))
}

function onDragEnd() {
  isDragging.value = false
  document.removeEventListener('mousemove', onDrag)
  document.removeEventListener('mouseup', onDragEnd)
  document.body.style.cursor = ''
  document.body.style.userSelect = ''
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
      
      <!-- 组织架构 - 左右分栏 -->
      <div v-else-if="activeTab === 'organize'" class="tab-content organize-layout">
        <!-- 左侧部门树 -->
        <aside class="dept-sidebar" :style="{ width: sidebarWidth + 'px' }">
          <div class="sidebar-header">组织部门</div>
          <n-scrollbar class="dept-scroll">
            <div class="dept-tree">
              <DeptTreeNode
                v-for="dept in deptTree"
                :key="dept.dept_id"
                :dept="dept"
                :expanded-keys="expandedKeys"
                :selected-dept-id="selectedDeptId"
                :user-count-fn="getDeptUserCount"
                @toggle-expand="toggleExpand"
                @select-dept="selectDept"
              />
            </div>
          </n-scrollbar>
        </aside>

        <!-- 拖动分割条 -->
        <div
          class="splitter"
          :class="{ dragging: isDragging }"
          @mousedown="onDragStart"
        >
          <div class="splitter-handle"></div>
        </div>

        <!-- 右侧人员列表 -->
        <main class="member-panel">
          <!-- 面板头部 -->
          <header class="panel-header">
            <div class="header-title">
              <span class="dept-name">{{ selectedDept?.dept_name || '请选择部门' }}</span>
              <span class="member-count">({{ currentDeptUsers.length }}人)</span>
            </div>
            <n-input
              v-model:value="keywords"
              placeholder="搜索成员"
              clearable
              size="small"
              class="search-input"
            >
              <template #prefix>
                <n-icon :component="Search" />
              </template>
            </n-input>
          </header>

          <!-- 人员列表 -->
          <n-scrollbar class="member-scroll">
            <div v-if="currentDeptUsers.length" class="member-list">
              <div
                v-for="item in currentDeptUsers"
                :key="item.user_id"
                class="member-card"
              >
                <div class="member-avatar" @click="onShowUserInfo(item)">
                  <im-avatar :src="item.avatar" :size="44" :username="item.nickname" />
                </div>
                <div class="member-info" @click="onShowUserInfo(item)">
                  <div class="member-name">
                    {{ item.nickname }}
                    <n-icon v-if="item.gender === 1" :component="Male" color="#508afe" size="14" />
                    <n-icon v-if="item.gender === 2" :component="Female" color="#ff5722" size="14" />
                  </div>
                  <div v-if="item.position_items?.length" class="member-position">
                    {{ item.position_items.map((p: any) => p.name).join('、') }}
                  </div>
                  <div v-else class="member-dept">{{ item.dept_item?.dept_name }}</div>
                </div>
                <div class="member-actions">
                  <n-button 
                    type="primary" 
                    size="small"
                    @click="onToTalk(item)"
                  >
                    发送消息
                  </n-button>
                </div>
              </div>
            </div>
            <div v-else class="empty-state">
              <n-empty description="暂无成员" size="small" />
            </div>
          </n-scrollbar>
        </main>
      </div>
    </div>
  </div>
</template>

<script lang="ts">
import GroupList from '@/views/contact/group.vue'
import DeptTreeNode from './DeptTreeNode.vue'

export default {
  components: {
    GroupList,
    DeptTreeNode
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

      // 组织架构左右分栏布局
      &.organize-layout {
        display: flex;

        // 左侧部门树
        .dept-sidebar {
          background: #fff;
          border-right: 1px solid #e8e8e8;
          display: flex;
          flex-direction: column;
          flex-shrink: 0;

          .sidebar-header {
            padding: 12px 16px;
            font-size: 14px;
            font-weight: 500;
            color: #333;
            border-bottom: 1px solid #f0f0f0;
          }

          .dept-scroll {
            flex: 1;

            .dept-tree {
              padding: 8px 0;
            }
          }
        }

        // 拖动分割条
        .splitter {
          width: 6px;
          background: #f0f0f0;
          cursor: col-resize;
          display: flex;
          align-items: center;
          justify-content: center;
          flex-shrink: 0;
          position: relative;
          transition: background 0.2s;

          &:hover {
            background: #d9d9d9;

            .splitter-handle {
              opacity: 1;
            }
          }

          &.dragging {
            background: #1890ff;
            user-select: none;
          }

          .splitter-handle {
            width: 3px;
            height: 20px;
            background: #999;
            border-radius: 2px;
            opacity: 0;
            transition: opacity 0.2s;
          }
        }

        // 右侧人员面板
        .member-panel {
          flex: 1;
          display: flex;
          flex-direction: column;
          overflow: hidden;

          .panel-header {
            display: flex;
            align-items: center;
            justify-content: space-between;
            padding: 12px 16px;
            background: #fff;
            border-bottom: 1px solid #f0f0f0;
            flex-shrink: 0;

            .header-title {
              display: flex;
              align-items: center;
              gap: 8px;

              .dept-name {
                font-size: 15px;
                font-weight: 500;
                color: #333;
              }

              .member-count {
                font-size: 13px;
                color: #999;
              }
            }

            .search-input {
              width: 160px;
            }
          }

          .member-scroll {
            flex: 1;
            background: #f5f5f5;

            .member-list {
              padding: 12px;

              .member-card {
                display: flex;
                align-items: center;
                padding: 12px 16px;
                background: #fff;
                border-radius: 8px;
                margin-bottom: 10px;
                transition: all 0.2s;
                border: 1px solid transparent;

                &:hover {
                  border-color: #1890ff;
                  box-shadow: 0 2px 8px rgba(24, 144, 255, 0.1);

                  .member-actions {
                    opacity: 1;
                  }
                }

                .member-avatar {
                  flex-shrink: 0;
                  margin-right: 12px;
                  cursor: pointer;
                }

                .member-info {
                  flex: 1;
                  min-width: 0;
                  cursor: pointer;

                  .member-name {
                    display: flex;
                    align-items: center;
                    gap: 6px;
                    font-size: 15px;
                    font-weight: 500;
                    color: #333;
                    margin-bottom: 4px;
                  }

                  .member-position,
                  .member-dept {
                    font-size: 12px;
                    color: #999;
                    overflow: hidden;
                    text-overflow: ellipsis;
                    white-space: nowrap;
                  }

                  .member-position {
                    color: #666;
                  }
                }

                .member-actions {
                  flex-shrink: 0;
                  opacity: 0;
                  transition: opacity 0.2s;
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
      }
    }
  }
}
</style>
