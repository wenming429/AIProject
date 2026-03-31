<script lang="ts" setup>
import { useUserStore, useTalkStore } from '@/store'
import { Search, Male, Female, Right, DownOne } from '@icon-park/vue-next'
import { useInject } from '@/hooks'
import { ref, computed, h } from 'vue'
import { fetchOrganizeDepartmentList, fetchOrganizePersonnelList } from '@/apis/api'
import { fetchApi } from '@/apis/request'
import { NTag } from 'naive-ui'

const userStore = useUserStore()
const talkStore = useTalkStore()
const router = useRouter()
const { toShowUserInfo, message } = useInject()

const keywords = ref('')
const deptTree = ref<any[]>([])
const personnelList = ref<any[]>([])
const expandedKeys = ref<number[]>([])
const selectedDeptId = ref<number | null>(null)

// 将部门列表转为树形结构
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

// 递归获取所有部门ID
function getAllDeptIds(tree: any[]): number[] {
  const ids: number[] = []
  tree.forEach(node => {
    ids.push(node.dept_id)
    if (node.children?.length) {
      ids.push(...getAllDeptIds(node.children))
    }
  })
  return ids
}

// 过滤人员
const filteredPersonnel = computed(() => {
  let list = personnelList.value
  
  // 按部门筛选
  if (selectedDeptId.value) {
    const selectedDept = findDeptById(deptTree.value, selectedDeptId.value)
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

// 查找部门
function findDeptById(tree: any[], id: number): any {
  for (const node of tree) {
    if (node.dept_id === id) return node
    if (node.children?.length) {
      const found = findDeptById(node.children, id)
      if (found) return found
    }
  }
  return null
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
  deptTree.value = buildTree(list)
  
  // 默认展开第一级
  if (deptTree.value.length > 0) {
    expandedKeys.value = deptTree.value.map(d => d.dept_id)
  }
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

// 递归渲染部门树
function renderDeptTree(tree: any[], level = 0) {
  return tree.map(dept => {
    const isExpanded = expandedKeys.value.includes(dept.dept_id)
    const isSelected = selectedDeptId.value === dept.dept_id
    const hasChildren = dept.children?.length > 0
    
    // 计算该部门下的人员数量
    const count = personnelList.value.filter(p => {
      const pDeptId = p.dept_item?.dept_id
      if (pDeptId === dept.dept_id) return true
      // 如果展开，也计算子部门人员
      if (isExpanded) {
        const childIds = getChildDeptIds(dept)
        return childIds.includes(pDeptId)
      }
      return false
    }).length
    
    return h('div', {
      class: 'dept-node',
      style: { paddingLeft: `${level * 16}px` }
    }, [
      h('div', {
        class: ['dept-item', { selected: isSelected }],
        onClick: () => selectDept(dept)
      }, [
        hasChildren ? h('span', {
          class: 'expand-icon',
          onClick: (e: Event) => {
            e.stopPropagation()
            toggleExpand(dept)
          }
        }, h(isExpanded ? DownOne : Right, { theme: 'filled', size: 12 })) : h('span', { class: 'expand-placeholder' }),
        h('span', { class: 'dept-name' }, dept.dept_name),
        h('span', { class: 'dept-count' }, `${count}人`)
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
    <!-- 搜索栏 -->
    <header class="organize-header">
      <n-input
        v-model:value="keywords"
        placeholder="搜索成员"
        clearable
        size="small"
        style="width: 100%"
      >
        <template #prefix>
          <n-icon :component="Search" />
        </template>
      </n-input>
    </header>

    <!-- 内容区 -->
    <div class="organize-body">
      <!-- 左侧部门树 -->
      <aside class="dept-tree">
        <div class="tree-header">企业组织</div>
        <n-scrollbar>
          <div class="tree-content">
            <component :is="() => renderDeptTree(deptTree)" />
          </div>
        </n-scrollbar>
      </aside>

      <!-- 右侧成员列表 -->
      <main class="member-list">
        <n-scrollbar>
          <div v-if="filteredPersonnel.length" class="member-items">
            <div
              v-for="item in filteredPersonnel"
              :key="item.user_id"
              class="member-item"
            >
              <div class="member-avatar" @click="onShowUserInfo(item)">
                <im-avatar :src="item.avatar" :size="36" :username="item.nickname" />
              </div>
              <div class="member-info" @click="onShowUserInfo(item)">
                <div class="member-name">
                  <n-icon v-if="item.gender == 1" :component="Male" color="#508afe" size="14" />
                  <n-icon v-if="item.gender == 2" :component="Female" color="#ff5722" size="14" />
                  <span>{{ item.remark || item.nickname }}</span>
                  <n-tag
                    v-for="(pos, index) in item.position_items"
                    :key="index"
                    size="tiny"
                    type="info"
                  >{{ pos.name }}</n-tag>
                </div>
                <div class="member-dept">{{ item.dept_item?.dept_name }}</div>
              </div>
              <div class="member-action">
                <n-button text size="tiny" type="primary" @click="onToTalk(item)">
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
  </div>
</template>

<style lang="less" scoped>
.embedded-organize {
  height: 100%;
  display: flex;
  flex-direction: column;
  background: #f5f5f5;

  .organize-header {
    padding: 10px 12px;
    background: #fff;
    border-bottom: 1px solid #e8e8e8;
    flex-shrink: 0;
  }

  .organize-body {
    flex: 1;
    display: flex;
    overflow: hidden;

    .dept-tree {
      width: 160px;
      background: #fff;
      border-right: 1px solid #e8e8e8;
      flex-shrink: 0;
      display: flex;
      flex-direction: column;

      .tree-header {
        padding: 10px 12px;
        font-size: 13px;
        font-weight: 500;
        color: #333;
        border-bottom: 1px solid #f0f0f0;
      }

      .tree-content {
        padding: 8px 0;

        .dept-node {
          .dept-item {
            display: flex;
            align-items: center;
            padding: 6px 12px;
            cursor: pointer;
            font-size: 12px;
            color: #333;
            transition: all 0.2s;

            &:hover {
              background: #f5f5f5;
            }

            &.selected {
              background: #8B0000;
              color: #fff;

              .dept-count {
                color: rgba(255, 255, 255, 0.7);
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

              &:hover {
                background: rgba(0, 0, 0, 0.05);
              }
            }

            .expand-placeholder {
              width: 16px;
              margin-right: 4px;
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
            }
          }
        }
      }
    }

    .member-list {
      flex: 1;
      overflow: hidden;
      background: #f5f5f5;

      .member-items {
        padding: 8px;

        .member-item {
          display: flex;
          align-items: center;
          padding: 8px;
          background: #fff;
          border-radius: 4px;
          margin-bottom: 8px;
          cursor: pointer;
          transition: all 0.2s;

          &:hover {
            box-shadow: 0 2px 8px rgba(0, 0, 0, 0.08);
          }

          .member-avatar {
            flex-shrink: 0;
            margin-right: 10px;
          }

          .member-info {
            flex: 1;
            min-width: 0;

            .member-name {
              display: flex;
              align-items: center;
              gap: 6px;
              font-size: 13px;
              color: #333;
              margin-bottom: 2px;

              span {
                overflow: hidden;
                text-overflow: ellipsis;
                white-space: nowrap;
              }
            }

            .member-dept {
              font-size: 11px;
              color: #999;
            }
          }

          .member-action {
            flex-shrink: 0;
          }
        }
      }

      .empty-state {
        height: 200px;
        display: flex;
        align-items: center;
        justify-content: center;
      }
    }
  }
}
</style>
