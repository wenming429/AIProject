<script lang="ts" setup>
import { fetchGroupCreate, fetchGroupGetInviteFriends, fetchGroupInvite, fetchOrganizeDepartmentList, fetchOrganizePersonnelList } from '@/apis/api'
import { fetchApi } from '@/apis/request'
import { useInject, useThemeMode } from '@/hooks'
import { Search, Close, Right, DownOne, User, AddOne, Minus, FolderOpen, FolderClose, Peoples, Check } from '@icon-park/vue-next'
import { NAvatar, NScrollbar, NTag, NCheckbox } from 'naive-ui'
import TreeNode from '@/components/tree/TreeNode.vue'

const { message } = useInject()
const { currentTheme } = useThemeMode()

const props = defineProps<{
  groupId: number
}>()

const emit = defineEmits<{
  close: []
  onInvite: [groupId: number]
  onSubmit: [groupId: number, groupName: string]
}>()

// 弹窗控制
const isShowBox = ref(true)
const modelGroupName = ref('')
const loading = ref(true)

// 组织架构相关数据
const deptTree = ref<any[]>([])
const personnelList = ref<any[]>([])
const expandedKeys = ref<number[]>([])
const selectedDeptId = ref<number | null>(null)
const keywords = ref('')

// 已选中的用户ID列表（用于批量勾选）
const selectedUserIds = ref<Set<number>>(new Set())
// 已选中的用户完整信息列表
const selectedUsers = ref<any[]>([])

// 头像映射
const mapData = new Map()

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
      item.position_items?.sort((a: any, b: any) => a.sort - b.sort)
      mapData.set(item.user_id, item.avatar)
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
  let users = personnelList.value.filter(p => 
    deptIds.includes(p.dept_item?.dept_id)
  )

  if (keywords.value) {
    const kw = keywords.value.toLowerCase()
    users = users.filter(p => 
      p.nickname?.toLowerCase().includes(kw) ||
      p.position_items?.some((pos: any) => pos.name.toLowerCase().includes(kw))
    )
  }

  return users.sort((a, b) => a.nickname.localeCompare(b.nickname, 'zh-CN'))
})

// 获取部门下的人员数量
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

// 检查部门是否展开
function isExpanded(deptId: number): boolean {
  return expandedKeys.value.includes(deptId)
}

// 检查用户是否已选中
function isUserSelected(userId: number): boolean {
  return selectedUserIds.value.has(userId)
}

// 切换用户选中状态
function toggleUserSelection(user: any) {
  if (selectedUserIds.value.has(user.user_id)) {
    selectedUserIds.value.delete(user.user_id)
    selectedUsers.value = selectedUsers.value.filter(u => u.user_id !== user.user_id)
  } else {
    selectedUserIds.value.add(user.user_id)
    selectedUsers.value.push(user)
  }
}

// 从已选列表移除用户
function removeUser(userId: number) {
  selectedUserIds.value.delete(userId)
  selectedUsers.value = selectedUsers.value.filter(u => u.user_id !== userId)
}

// 全选当前部门成员
function selectAll() {
  currentDeptUsers.value.forEach(user => {
    if (!selectedUserIds.value.has(user.user_id)) {
      selectedUserIds.value.add(user.user_id)
      selectedUsers.value.push(user)
    }
  })
}

// 取消全选当前部门成员
function unselectAll() {
  currentDeptUsers.value.forEach(user => {
    selectedUserIds.value.delete(user.user_id)
  })
  selectedUsers.value = selectedUsers.value.filter(u => 
    !currentDeptUsers.value.some(cu => cu.user_id === u.user_id)
  )
}

// 是否已全选当前部门成员
const isAllSelected = computed(() => {
  if (currentDeptUsers.value.length === 0) return false
  return currentDeptUsers.value.every(user => selectedUserIds.value.has(user.user_id))
})

// 是否可以提交
const isCanSubmit = computed(() => {
  if (selectedUsers.value.length === 0) return true
  if (props.groupId === 0 && modelGroupName.value.trim() === '') return true
  return false
})

// 关闭弹窗
const close = () => {
  emit('close')
}

// 创建群聊提交
const onCreateSubmit = async (user_ids: number[]) => {
  if (modelGroupName.value.trim() == '') {
    return message.error('请输入群名称')
  }

  const [err, data] = await fetchApi(fetchGroupCreate, {
    user_ids,
    name: modelGroupName.value.trim()
  })

  if (err) return

  message.success('创建成功')
  emit('onSubmit', data.group_id, modelGroupName.value.trim())
  emit('close')
}

// 邀请好友提交
const onInviteSubmit = async (user_ids: number[]) => {
  const [err] = await fetchApi(fetchGroupInvite, {
    user_ids,
    group_id: props.groupId
  })

  if (err) return

  message.success('邀请成功')
  emit('onInvite', props.groupId)
  emit('close')
}

// 提交
const onSubmit = () => {
  const ids = selectedUsers.value.map(u => u.user_id)

  if (props.groupId == 0) {
    onCreateSubmit(ids)
  } else {
    onInviteSubmit(ids)
  }
}

onMounted(() => {
  loadOrganizeData()
})
</script>

<template>
  <n-modal
    v-model:show="isShowBox"
    preset="card"
    :title="groupId === 0 ? '创建群聊' : '邀请好友'"
    class="modal-radius group-launch-modal"
    style="width: 900px; max-width: 95vw;"
    :on-after-leave="close"
    transform-origin="mouse"
  >
    <section class="launch-box">
      <!-- 创建群聊时显示群名称输入 -->
      <div v-if="groupId === 0" class="group-name-section">
        <span class="section-label">群名称</span>
        <n-input
          placeholder="请填写群名称"
          maxlength="20"
          show-count
          v-model:value="modelGroupName"
          class="group-name-input"
        />
      </div>

      <!-- 三栏布局 -->
      <div class="three-column-layout">
        <!-- 第一栏：组织架构树 -->
        <aside class="dept-sidebar">
          <div class="sidebar-header">
            <n-icon :component="FolderOpen" :size="16" />
            <span>组织架构</span>
          </div>
          <n-scrollbar class="dept-scroll">
            <div class="dept-tree">
              <TreeNode
                v-for="dept in deptTree"
                :key="dept.dept_id"
                :item="dept"
                :expandedKeys="expandedKeys"
                :selectedKey="selectedDeptId"
                @toggle="toggleExpand"
                @select="selectDept"
              />
            </div>
          </n-scrollbar>
        </aside>

        <!-- 第二栏：人员列表 -->
        <main class="member-panel">
          <div class="panel-header">
            <div class="breadcrumb-path">
              <span class="path-item">集团总部</span>
              <span class="path-separator">/</span>
              <span class="path-item current">{{ selectedDept?.dept_name || '请选择部门' }}</span>
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
          </div>

          <div class="panel-toolbar">
            <n-checkbox 
              :checked="isAllSelected" 
              @update:checked="isAllSelected ? unselectAll() : selectAll()"
              :disabled="currentDeptUsers.length === 0"
            >
              全选
            </n-checkbox>
            <span class="selected-tip">已选 {{ selectedUsers.length }} 人</span>
          </div>

          <n-scrollbar class="member-scroll">
            <div v-if="currentDeptUsers.length" class="member-list">
              <div
                v-for="item in currentDeptUsers"
                :key="item.user_id"
                class="member-card"
                :class="{ selected: isUserSelected(item.user_id) }"
              >
                <n-checkbox
                  :checked="isUserSelected(item.user_id)"
                  @update:checked="toggleUserSelection(item)"
                  class="member-checkbox"
                />
                <div class="member-avatar">
                  <im-avatar
                    :src="item.avatar"
                    :size="40"
                    :username="item.nickname"
                  />
                </div>
                <div class="member-info">
                  <div class="member-name-row">
                    <span class="member-name">{{ item.nickname }}</span>
                    <n-tag
                      v-for="(pos, idx) in item.position_items?.slice(0, 1)"
                      :key="idx"
                      size="small"
                      type="info"
                      class="position-tag"
                    >
                      {{ pos.name }}
                    </n-tag>
                  </div>
                  <div class="member-dept">
                    {{ item.dept_item?.dept_name }}
                    <span v-if="item.position_items?.length">· {{ item.position_items.map((p: any) => p.name).join('、') }}</span>
                  </div>
                </div>
                <div class="member-action">
                  <button 
                    class="add-btn"
                    :class="{ added: isUserSelected(item.user_id) }"
                    @click="toggleUserSelection(item)"
                  >
                    <n-icon :component="isUserSelected(item.user_id) ? Check : AddOne" :size="16" />
                  </button>
                </div>
              </div>
            </div>
            <div v-else class="empty-state">
              <div class="empty-icon">
                <n-icon :component="Peoples" :size="28" />
              </div>
              <p>暂无成员</p>
            </div>
          </n-scrollbar>
        </main>

        <!-- 第三栏：已选用户 -->
        <aside class="selected-sidebar">
          <div class="sidebar-header">
            <n-icon :component="User" :size="16" />
            <span>已选成员</span>
            <span class="selected-count">({{ selectedUsers.length }})</span>
          </div>

          <n-scrollbar class="selected-scroll">
            <div v-if="selectedUsers.length" class="selected-list">
              <div
                v-for="user in selectedUsers"
                :key="user.user_id"
                class="selected-card"
              >
                <div class="selected-avatar">
                  <im-avatar
                    :src="user.avatar"
                    :size="36"
                    :username="user.nickname"
                  />
                </div>
                <div class="selected-info">
                  <div class="selected-name">{{ user.nickname }}</div>
                  <div class="selected-dept">{{ user.dept_item?.dept_name }}</div>
                </div>
                <div class="selected-action">
                  <button class="remove-btn" @click="removeUser(user.user_id)">
                    <n-icon :component="Minus" :size="14" />
                  </button>
                </div>
              </div>
            </div>
            <div v-else class="empty-state">
              <div class="empty-icon">
                <n-icon :component="AddOne" :size="28" />
              </div>
              <p>点击添加成员</p>
            </div>
          </n-scrollbar>
        </aside>
      </div>
    </section>

    <template #footer>
      <div class="dialog-footer">
        <button 
          class="btn btn-default" 
          @click="isShowBox = false"
          :style="{
            color: currentTheme.textPrimary,
            background: currentTheme.bgColor,
            borderColor: currentTheme.borderColor
          }"
        >
          取消
        </button>
        <button 
          class="btn btn-primary" 
          @click="onSubmit"
          :disabled="isCanSubmit"
          :style="{
            background: currentTheme.primary,
            color: currentTheme.textInverse
          }"
        >
          确定
        </button>
      </div>
    </template>
  </n-modal>

</template>

<style lang="less" scoped>
// 颜色变量
@bg-primary: #ffffff;
@bg-secondary: #f5f7fa;
@bg-tertiary: #f0f2f5;
@border-color: #e4e7ed;
@border-light: #ebeef5;
@text-primary: #303133;
@text-secondary: #606266;
@text-tertiary: #909399;
@primary-color: #409eff;
@primary-light: #ecf5ff;
@success-color: #67c23a;
@shadow-sm: 0 2px 12px 0 rgba(0, 0, 0, 0.05);

.launch-box {
  width: 100%;
  overflow: hidden;
  background: @bg-primary;

  .group-name-section {
    display: flex;
    align-items: center;
    gap: 12px;
    padding: 16px 20px;
    border-bottom: 1px solid @border-light;
    background: @bg-primary;

    .section-label {
      font-size: 14px;
      color: @text-primary;
      font-weight: 500;
      white-space: nowrap;
    }

    .group-name-input {
      flex: 1;
      max-width: 400px;

      :deep(.n-input__input) {
        font-size: 14px;
      }
    }
  }
}

.three-column-layout {
  display: flex;
  height: 480px;
  background: @bg-secondary;
  overflow: hidden;
}

// 左侧部门树
.dept-sidebar {
  width: 220px;
  flex-shrink: 0;
  background: @bg-primary;
  border-right: 1px solid @border-light;
  display: flex;
  flex-direction: column;

  .sidebar-header {
    padding: 14px 16px;
    font-size: 14px;
    font-weight: 600;
    color: @text-primary;
    border-bottom: 1px solid @border-light;
    background: @bg-primary;
    display: flex;
    align-items: center;
    gap: 8px;

    .n-icon {
      color: @text-secondary;
    }
  }

  .dept-scroll {
    flex: 1;

    .dept-tree {
      padding: 8px 0;

      ::v-deep(.tree-node) {
        .tree-node-content {
          padding: 9px 12px;
          margin: 2px 8px;
          border-radius: 4px;
          color: @text-primary;
          font-size: 13px;
          transition: all 0.2s ease;

          &:hover {
            background-color: @bg-secondary;
          }

          &.selected {
            background-color: @primary-light;
            color: @primary-color;
            font-weight: 500;

            .folder-icon {
              color: @primary-color;
            }
          }

          .expand-icon {
            .arrow-icon {
              color: @text-tertiary;
              font-size: 12px;
            }

            &:hover {
              background-color: @bg-tertiary;
            }
          }

          .folder-icon {
            color: @text-secondary;
            font-size: 14px;
          }

          .node-label {
            font-size: 13px;
          }

          .node-count {
            color: @text-tertiary;
            font-size: 12px;
          }
        }
      }
    }
  }
}

// 中间人员列表
.member-panel {
  flex: 1;
  display: flex;
  flex-direction: column;
  overflow: hidden;
  background: @bg-secondary;
  min-width: 0;

  .panel-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 12px 16px;
    background: @bg-primary;
    border-bottom: 1px solid @border-light;
    flex-shrink: 0;

    .breadcrumb-path {
      display: flex;
      align-items: center;
      gap: 6px;
      font-size: 13px;
      color: @text-secondary;
      overflow: hidden;
      flex: 1;
      min-width: 0;

      .path-item {
        white-space: nowrap;

        &.current {
          color: @text-primary;
          font-weight: 500;
        }
      }

      .path-separator {
        color: @text-tertiary;
      }

      .member-count {
        color: @text-tertiary;
        margin-left: 4px;
        white-space: nowrap;
      }
    }

    .search-input {
      width: 180px;
      flex-shrink: 0;

      :deep(.n-input__input) {
        font-size: 13px;
      }
    }
  }

  .panel-toolbar {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 10px 16px;
    background: @bg-primary;
    border-bottom: 1px solid @border-light;
    flex-shrink: 0;

    .selected-tip {
      font-size: 12px;
      color: @text-tertiary;
    }
  }

  .member-scroll {
    flex: 1;
    padding: 12px;

    .member-list {
      display: flex;
      flex-direction: column;
      gap: 8px;

      .member-card {
        display: flex;
        align-items: center;
        padding: 10px 12px;
        background: @bg-primary;
        border-radius: 6px;
        border: 1px solid transparent;
        transition: all 0.2s ease;

        &:hover {
          box-shadow: @shadow-sm;
          border-color: @border-color;
        }

        &.selected {
          border-color: @primary-color;
          background: @primary-light;
        }

        .member-checkbox {
          margin-right: 10px;
        }

        .member-avatar {
          flex-shrink: 0;
          margin-right: 10px;
        }

        .member-info {
          flex: 1;
          min-width: 0;
          display: flex;
          flex-direction: column;
          gap: 3px;

          .member-name-row {
            display: flex;
            align-items: center;
            gap: 8px;

            .member-name {
              font-size: 14px;
              font-weight: 500;
              color: @text-primary;
            }

            .position-tag {
              font-size: 11px;
              height: 20px;
              line-height: 18px;
              padding: 0 8px;
              background: @primary-light;
              color: @primary-color;
              border: none;
            }
          }

          .member-dept {
            font-size: 12px;
            color: @text-tertiary;
            overflow: hidden;
            text-overflow: ellipsis;
            white-space: nowrap;
          }
        }

        .member-action {
          flex-shrink: 0;
          margin-left: 8px;

          .add-btn {
            width: 28px;
            height: 28px;
            display: flex;
            align-items: center;
            justify-content: center;
            background: @bg-primary;
            border: 1px solid @border-color;
            border-radius: 50%;
            color: @text-secondary;
            cursor: pointer;
            transition: all 0.2s ease;

            &:hover {
              border-color: @primary-color;
              color: @primary-color;
              background: @primary-light;
            }

            &.added {
              background: @success-color;
              border-color: @success-color;
              color: @bg-primary;

              &:hover {
                background: #85ce61;
                border-color: #85ce61;
              }
            }
          }
        }
      }
    }

    .empty-state {
      height: 100%;
      min-height: 300px;
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      color: @text-tertiary;
      gap: 12px;

      .empty-icon {
        width: 60px;
        height: 60px;
        border-radius: 50%;
        background: @bg-primary;
        border: 1px dashed @border-color;
        display: flex;
        align-items: center;
        justify-content: center;
        color: @text-tertiary;
      }

      p {
        margin: 0;
        font-size: 13px;
        color: @text-secondary;
      }
    }
  }
}

// 右侧已选列表
.selected-sidebar {
  width: 240px;
  flex-shrink: 0;
  background: @bg-primary;
  border-left: 1px solid @border-light;
  display: flex;
  flex-direction: column;

  .sidebar-header {
    padding: 14px 16px;
    font-size: 14px;
    font-weight: 600;
    color: @text-primary;
    border-bottom: 1px solid @border-light;
    background: @bg-primary;
    display: flex;
    align-items: center;
    gap: 8px;

    .n-icon {
      color: @text-secondary;
    }

    .selected-count {
      font-size: 12px;
      font-weight: normal;
      color: @text-tertiary;
      margin-left: auto;
    }
  }

  .selected-scroll {
    flex: 1;
    padding: 12px;

    .selected-list {
      display: flex;
      flex-direction: column;
      gap: 8px;

      .selected-card {
        display: flex;
        align-items: center;
        padding: 10px 12px;
        background: @bg-secondary;
        border-radius: 6px;
        border: 1px solid @border-light;
        transition: all 0.2s ease;

        &:hover {
          border-color: @primary-color;
          background: @primary-light;
        }

        .selected-avatar {
          flex-shrink: 0;
          margin-right: 10px;
        }

        .selected-info {
          flex: 1;
          min-width: 0;
          display: flex;
          flex-direction: column;
          gap: 2px;

          .selected-name {
            font-size: 13px;
            font-weight: 500;
            color: @text-primary;
            overflow: hidden;
            text-overflow: ellipsis;
            white-space: nowrap;
          }

          .selected-dept {
            font-size: 11px;
            color: @text-tertiary;
            overflow: hidden;
            text-overflow: ellipsis;
            white-space: nowrap;
          }
        }

        .selected-action {
          flex-shrink: 0;
          margin-left: 8px;

          .remove-btn {
            width: 22px;
            height: 22px;
            display: flex;
            align-items: center;
            justify-content: center;
            background: @bg-primary;
            border: 1px solid @border-color;
            border-radius: 50%;
            color: @text-tertiary;
            cursor: pointer;
            transition: all 0.2s ease;

            &:hover {
              background: #fef0f0;
              border-color: #f56c6c;
              color: #f56c6c;
            }
          }
        }
      }
    }

    .empty-state {
      height: 100%;
      min-height: 300px;
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      color: @text-tertiary;
      gap: 12px;

      .empty-icon {
        width: 60px;
        height: 60px;
        border-radius: 50%;
        background: @bg-secondary;
        border: 1px dashed @border-color;
        display: flex;
        align-items: center;
        justify-content: center;
        color: @text-tertiary;
      }

      p {
        margin: 0;
        font-size: 13px;
        color: @text-secondary;
      }
    }
  }
}

// 底部按钮区域 - 使用主题皮肤样式
.dialog-footer {
  display: flex;
  align-items: center;
  justify-content: flex-end;
  gap: 12px;
  padding: 16px 20px;
  border-top: 1px solid var(--im-border-color, #ebeef5);
  background: var(--im-bg-color, #ffffff);

  .btn {
    padding: 9px 24px;
    font-size: 14px;
    border-radius: 4px;
    cursor: pointer;
    transition: all 0.2s ease;
    border: 1px solid transparent;
    outline: none;

    &.btn-default {
      &:hover {
        opacity: 0.8;
      }
    }

    &.btn-primary {
      &:hover:not(:disabled) {
        opacity: 0.9;
        box-shadow: 0 2px 8px rgba(0, 0, 0, 0.15);
      }

      &:disabled {
        opacity: 0.5;
        cursor: not-allowed;
      }
    }
  }
}
</style>

<style lang="less">
// 全局样式调整 - 覆盖 Naive UI 默认样式
.group-launch-modal {
  .n-card {
    border-radius: 8px;
    box-shadow: 0 4px 24px rgba(0, 0, 0, 0.1);

    .n-card-header {
      padding: 16px 20px;
      border-bottom: 1px solid #ebeef5;

      .n-card-header__main {
        font-size: 16px;
        font-weight: 600;
        color: #303133;
      }
    }

    .n-card__content {
      padding: 0 !important;
    }

    .n-card__footer {
      padding: 0 !important;
    }
  }
}

// 响应式适配
@media (max-width: 768px) {
  .group-launch-modal {
    width: 100vw !important;
    max-width: 100vw !important;
    margin: 0 !important;
    border-radius: 0 !important;

    .n-card {
      border-radius: 0;
    }
  }

  .three-column-layout {
    flex-direction: column;
    height: auto;
    max-height: 70vh;
    overflow-y: auto;

    .dept-sidebar,
    .selected-sidebar {
      width: 100%;
      border: none;
      border-bottom: 1px solid #ebeef5;
      max-height: 200px;
    }

    .member-panel {
      min-height: 300px;
    }
  }
}
</style>
