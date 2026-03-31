<script lang="ts" setup>
import { useUserStore, useTalkStore } from '@/store'
import { Search, Male, Female, Right, DownOne, AddOne, ListView, TreeDiagram } from '@icon-park/vue-next'
import { useInject } from '@/hooks'
import { ref, computed, h, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { fetchOrganizeDepartmentList, fetchOrganizePersonnelList } from '@/apis/api'
import { fetchApi } from '@/apis/request'

const userStore = useUserStore()
const talkStore = useTalkStore()
const router = useRouter()
const { toShowUserInfo, message } = useInject()

const keywords = ref('')
const deptTree = ref<any[]>([])
const personnelList = ref<any[]>([])
const expandedKeys = ref<number[]>([])
const selectedDeptId = ref<number | null>(null)
const viewMode = ref<'list' | 'tree'>('list') // 视图模式：列表/树状

// 构建部门树，添加"企业组织"作为根节点
function buildTreeWithRoot(list: any[]): any[] {
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
  
  // 添加企业组织作为根节点
  return [{
    dept_id: 0,
    dept_name: '企业组织',
    parent_id: null,
    children: tree,
    isRoot: true
  }]
}

// 过滤人员
const filteredPersonnel = computed(() => {
  let list = personnelList.value
  
  // 按部门筛选（如果选中了具体部门，不是根节点）
  if (selectedDeptId.value !== null && selectedDeptId.value !== 0) {
    const allDepts = flattenDeptTree(deptTree.value)
    const selectedDept = allDepts.find(d => d.dept_id === selectedDeptId.value)
    if (selectedDept) {
      const deptIds = [selectedDept.dept_id, ...getChildDeptIds(selectedDept)]
      list = list.filter(p => deptIds.includes(p.dept_item?.dept_id))
    }
  }
  
  // 按关键词筛选
  if (keywords.value) {
    const kw = keywords.value.toLowerCase()
    list = list.filter(p => 
      p.nickname?.toLowerCase().includes(kw) ||
      p.remark?.toLowerCase().includes(kw) ||
      p.position?.toLowerCase().includes(kw)
    )
  }
  
  return list.sort((a, b) => a.nickname.localeCompare(b.nickname, 'zh-CN'))
})

// 扁平化部门树
function flattenDeptTree(tree: any[]): any[] {
  const result: any[] = []
  tree.forEach(node => {
    result.push(node)
    if (node.children?.length) {
      result.push(...flattenDeptTree(node.children))
    }
  })
  return result
}

// 获取子部门ID列表
function getChildDeptIds(dept: any): number[] {
  const ids: number[] = []
  if (dept.children?.length) {
    dept.children.forEach((child: any) => {
      ids.push(child.dept_id)
      ids.push(...getChildDeptIds(child))
    })
  }
  return ids
}

// 加载部门数据
async function loadDepartments() {
  const [err, data] = await fetchApi(fetchOrganizeDepartmentList, {})
  if (err) return
  
  const list = data.items || []
  deptTree.value = buildTreeWithRoot(list)
  
  // 默认展开根节点
  expandedKeys.value = [0]
  selectedDeptId.value = 0
}

// 加载人员数据
async function loadPersonnel() {
  const [err, data] = await fetchApi(fetchOrganizePersonnelList, {})
  if (err) return
  
  const users = data.items || []
  users.forEach((item: any) => {
    item.position_items.sort((a: any, b: any) => a.sort - b.sort)
    item.position = item.position_items.map((p: any) => p.name).join('、')
  })
  
  personnelList.value = users
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

// 切换部门展开/收起
function toggleExpand(dept: any) {
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
}

// 邀请成员
function onInviteMember() {
  message.info('邀请成员功能开发中...')
}

// 递归渲染部门树
function renderDeptTree(tree: any[], level = 0) {
  return tree.map(dept => {
    const isExpanded = expandedKeys.value.includes(dept.dept_id)
    const isSelected = selectedDeptId.value === dept.dept_id
    const hasChildren = dept.children?.length > 0
    const isRoot = dept.isRoot
    
    // 计算该部门下的人员数量
    const count = isRoot 
      ? personnelList.value.length 
      : personnelList.value.filter(p => {
          const pDeptId = p.dept_item?.dept_id
          if (pDeptId === dept.dept_id) return true
          const childIds = getChildDeptIds(dept)
          return childIds.includes(pDeptId)
        }).length
    
    return h('div', {
      class: ['dept-node', { 'is-root': isRoot }],
      style: { paddingLeft: `${level * 12 + 8}px` }
    }, [
      h('div', {
        class: ['dept-item', { selected: isSelected, 'is-root': isRoot }],
        onClick: () => selectDept(dept)
      }, [
        hasChildren ? h('span', {
          class: 'expand-icon',
          onClick: (e: Event) => {
            e.stopPropagation()
            toggleExpand(dept)
          }
        }, h(isExpanded ? DownOne : Right, { theme: 'filled', size: 12 })) : h('span', { class: 'expand-placeholder' }),
        isRoot ? h('span', { class: 'root-icon' }, '🏢') : null,
        h('span', { class: 'dept-name' }, dept.dept_name),
        h('span', { class: 'dept-count' }, `${count}`)
      ]),
      hasChildren && isExpanded ? h('div', { class: 'dept-children' }, renderDeptTree(dept.children, level + 1)) : null
    ])
  })
}

onMounted(() => {
  loadDepartments()
  loadPersonnel()
})
</script>

<template>
  <div class="embedded-organize">
    <!-- 左侧部门树 -->
    <aside class="dept-sidebar">
      <div class="sidebar-header">
        <span class="header-title">组织架构</span>
      </div>
      <n-scrollbar class="tree-scroll">
        <div class="tree-content">
          <component :is="() => renderDeptTree(deptTree)" />
        </div>
      </n-scrollbar>
    </aside>

    <!-- 右侧成员列表 -->
    <main class="member-main">
      <!-- 顶部工具栏 -->
      <header class="member-header">
        <div class="header-left">
          <span class="current-dept">
            {{ selectedDeptId === 0 ? '企业组织' : flattenDeptTree(deptTree).find(d => d.dept_id === selectedDeptId)?.dept_name }}
          </span>
          <span class="member-count">({{ filteredPersonnel.length }}人)</span>
        </div>
        <div class="header-right">
          <!-- 视图切换 -->
          <n-radio-group v-model:value="viewMode" size="small" class="view-switch">
            <n-radio-button value="list">
              <n-icon :component="ListView" size="14" />
              <span>列表视图</span>
            </n-radio-button>
            <n-radio-button value="tree">
              <n-icon :component="TreeDiagram" size="14" />
              <span>树状视图</span>
            </n-radio-button>
          </n-radio-group>
          
          <!-- 搜索框 -->
          <n-input
            v-model:value="keywords"
            placeholder="搜索"
            clearable
            size="small"
            class="search-input"
          >
            <template #prefix>
              <n-icon :component="Search" />
            </template>
          </n-input>
        </div>
      </header>

      <!-- 邀请成员按钮 -->
      <div class="invite-section">
        <div class="invite-btn" @click="onInviteMember">
          <div class="invite-icon">
            <n-icon :component="AddOne" size="20" />
          </div>
          <span class="invite-text">邀请成员加入</span>
        </div>
      </div>

      <!-- 成员列表 -->
      <n-scrollbar class="member-scroll">
        <div v-if="filteredPersonnel.length" class="member-list">
          <div
            v-for="item in filteredPersonnel"
            :key="item.user_id"
            class="member-card"
            @click="onShowUserInfo(item)"
          >
            <!-- 头像 -->
            <div class="member-avatar-wrapper">
              <im-avatar 
                :src="item.avatar" 
                :size="40" 
                :username="item.nickname"
                class="member-avatar"
              />
            </div>
            
            <!-- 信息 -->
            <div class="member-info">
              <div class="member-row">
                <span class="member-name">{{ item.nickname }}</span>
                <!-- 管理员标签 -->
                <n-tag 
                  v-if="item.is_admin" 
                  size="tiny" 
                  type="warning"
                  class="admin-tag"
                >管理员</n-tag>
                <n-tag 
                  v-if="item.is_owner" 
                  size="tiny" 
                  type="error"
                  class="owner-tag"
                >所有者</n-tag>
              </div>
              <div class="member-row secondary">
                <span v-if="item.position_items?.length" class="member-position">
                  {{ item.position_items.map(p => p.name).join('、') }}
                </span>
                <span v-else class="member-dept">{{ item.dept_item?.dept_name }}</span>
              </div>
            </div>

            <!-- 操作 -->
            <div class="member-action">
              <n-button 
                text 
                size="small" 
                type="primary"
                @click.stop="onToTalk(item)"
              >
                发消息
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
</template>

<style lang="less" scoped>
.embedded-organize {
  height: 100%;
  display: flex;
  background: #f5f5f5;

  // 左侧部门树
  .dept-sidebar {
    width: 180px;
    background: #fff;
    border-right: 1px solid #e8e8e8;
    display: flex;
    flex-direction: column;
    flex-shrink: 0;

    .sidebar-header {
      padding: 12px 16px;
      border-bottom: 1px solid #f0f0f0;
      
      .header-title {
        font-size: 14px;
        font-weight: 500;
        color: #333;
      }
    }

    .tree-scroll {
      flex: 1;
      
      .tree-content {
        padding: 8px 0;

        .dept-node {
          &.is-root {
            > .dept-item {
              font-weight: 500;
            }
          }

          .dept-item {
            display: flex;
            align-items: center;
            padding: 8px 12px;
            cursor: pointer;
            font-size: 13px;
            color: #333;
            transition: all 0.2s;
            margin: 2px 8px;
            border-radius: 4px;

            &:hover {
              background: #f5f5f5;
            }

            &.selected {
              background: #e6f7ff;
              color: #1890ff;
              font-weight: 500;

              .dept-count {
                color: #1890ff;
              }
            }

            &.is-root {
              background: #f6ffed;
              
              &.selected {
                background: #d9f7be;
                color: #52c41a;
                
                .dept-count {
                  color: #52c41a;
                }
              }
            }

            .expand-icon {
              width: 16px;
              height: 16px;
              display: flex;
              align-items: center;
              justify-content: center;
              margin-right: 4px;
              cursor: pointer;
              border-radius: 2px;
              color: #999;

              &:hover {
                background: rgba(0, 0, 0, 0.05);
              }
            }

            .expand-placeholder {
              width: 16px;
              margin-right: 4px;
            }

            .root-icon {
              margin-right: 6px;
              font-size: 14px;
            }

            .dept-name {
              flex: 1;
              overflow: hidden;
              text-overflow: ellipsis;
              white-space: nowrap;
            }

            .dept-count {
              font-size: 11px;
              color: #999;
              margin-left: 4px;
              background: #f0f0f0;
              padding: 0 6px;
              border-radius: 10px;
              min-width: 20px;
              text-align: center;
            }
          }
        }
      }
    }
  }

  // 右侧主区域
  .member-main {
    flex: 1;
    display: flex;
    flex-direction: column;
    overflow: hidden;

    // 顶部工具栏
    .member-header {
      display: flex;
      align-items: center;
      justify-content: space-between;
      padding: 12px 16px;
      background: #fff;
      border-bottom: 1px solid #f0f0f0;
      flex-shrink: 0;

      .header-left {
        display: flex;
        align-items: center;
        gap: 8px;

        .current-dept {
          font-size: 15px;
          font-weight: 500;
          color: #333;
        }

        .member-count {
          font-size: 13px;
          color: #999;
        }
      }

      .header-right {
        display: flex;
        align-items: center;
        gap: 12px;

        .view-switch {
          .n-radio-button {
            display: flex;
            align-items: center;
            gap: 4px;
            
            span {
              font-size: 12px;
            }
          }
        }

        .search-input {
          width: 160px;
        }
      }
    }

    // 邀请按钮区域
    .invite-section {
      padding: 12px 16px;
      background: #fff;
      border-bottom: 1px solid #f0f0f0;
      flex-shrink: 0;

      .invite-btn {
        display: flex;
        align-items: center;
        gap: 12px;
        padding: 10px 12px;
        background: #f6ffed;
        border: 1px dashed #b7eb8f;
        border-radius: 6px;
        cursor: pointer;
        transition: all 0.2s;

        &:hover {
          background: #d9f7be;
          border-color: #73d13d;
        }

        .invite-icon {
          width: 32px;
          height: 32px;
          background: #52c41a;
          border-radius: 50%;
          display: flex;
          align-items: center;
          justify-content: center;
          color: #fff;
        }

        .invite-text {
          font-size: 14px;
          color: #52c41a;
          font-weight: 500;
        }
      }
    }

    // 成员列表
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
          margin-bottom: 8px;
          cursor: pointer;
          transition: all 0.2s;
          border: 1px solid transparent;

          &:hover {
            border-color: #1890ff;
            box-shadow: 0 2px 8px rgba(24, 144, 255, 0.1);
          }

          .member-avatar-wrapper {
            flex-shrink: 0;
            margin-right: 12px;

            .member-avatar {
              border-radius: 50%;
            }
          }

          .member-info {
            flex: 1;
            min-width: 0;
            display: flex;
            flex-direction: column;
            gap: 4px;

            .member-row {
              display: flex;
              align-items: center;
              gap: 8px;

              &.secondary {
                font-size: 12px;
                color: #999;
              }

              .member-name {
                font-size: 14px;
                font-weight: 500;
                color: #333;
              }

              .admin-tag,
              .owner-tag {
                font-size: 10px;
                padding: 0 4px;
                height: 18px;
                line-height: 16px;
              }

              .member-position,
              .member-dept {
                overflow: hidden;
                text-overflow: ellipsis;
                white-space: nowrap;
              }
            }
          }

          .member-action {
            flex-shrink: 0;
            margin-left: 12px;
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
</style>
