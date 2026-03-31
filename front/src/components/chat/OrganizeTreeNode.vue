<script lang="ts" setup>
import { Right, DownOne, Male, Female } from '@icon-park/vue-next'

const props = defineProps<{
  dept: any
  expandedKeys: number[]
  personnelList: any[]
  level?: number
}>()

const emit = defineEmits<{
  toggleExpand: [dept: any, event: Event]
  toTalk: [user: any, event: Event]
  showUserInfo: [user: any]
}>()

// 检查部门是否展开
const isExpanded = computed(() => {
  return props.expandedKeys.includes(props.dept.dept_id)
})

// 是否有子部门
const hasChildren = computed(() => {
  return props.dept.children?.length > 0
})

// 获取部门下的人员
const deptUsers = computed(() => {
  return props.personnelList.filter(p => p.dept_item?.dept_id === props.dept.dept_id)
})

// 切换展开
function onToggleExpand(e: Event) {
  emit('toggleExpand', props.dept, e)
}

// 发消息
function onToTalk(user: any, e: Event) {
  emit('toTalk', user, e)
}

// 显示用户信息
function onShowUserInfo(user: any) {
  emit('showUserInfo', user)
}
</script>

<template>
  <div class="organize-node" :style="{ paddingLeft: `${(level || 0) * 16}px` }">
    <!-- 部门节点 -->
    <div class="dept-row">
      <!-- 展开/收起按钮 -->
      <span
        v-if="hasChildren || deptUsers.length > 0"
        class="expand-btn"
        :class="{ expanded: isExpanded }"
        @click="onToggleExpand($event)"
      >
        <n-icon :component="isExpanded ? DownOne : Right" theme="filled" size="12" />
      </span>
      <span v-else class="expand-placeholder"></span>
      
      <!-- 部门图标 -->
      <span class="dept-icon">📁</span>
      
      <!-- 部门名称 -->
      <span class="dept-name">{{ dept.dept_name }}</span>
    </div>
    
    <!-- 展开后的内容 -->
    <div v-if="isExpanded" class="dept-children">
      <!-- 人员列表 -->
      <div
        v-for="user in deptUsers"
        :key="user.user_id"
        class="user-row"
        :style="{ paddingLeft: `${((level || 0) + 1) * 16 + 8}px` }"
        @click="onShowUserInfo(user)"
      >
        <span class="user-avatar">
          <im-avatar :src="user.avatar" :size="28" :username="user.nickname" />
        </span>
        <span class="user-info">
          <span class="user-name">
            {{ user.nickname }}
            <n-icon v-if="user.gender === 1" :component="Male" color="#508afe" size="12" />
            <n-icon v-if="user.gender === 2" :component="Female" color="#ff5722" size="12" />
          </span>
          <span v-if="user.position_items?.length" class="user-position">
            {{ user.position_items.map((p: any) => p.name).join('、') }}
          </span>
        </span>
        <span class="chat-btn" @click.stop="onToTalk(user, $event)">
          发消息
        </span>
      </div>
      
      <!-- 递归渲染子部门 -->
      <OrganizeTreeNode
        v-for="child in dept.children"
        :key="child.dept_id"
        :dept="child"
        :expanded-keys="expandedKeys"
        :personnel-list="personnelList"
        :level="(level || 0) + 1"
        @toggle-expand="(d, e) => $emit('toggleExpand', d, e)"
        @to-talk="(u, e) => $emit('toTalk', u, e)"
        @show-user-info="(u) => $emit('showUserInfo', u)"
      />
    </div>
  </div>
</template>

<style lang="less" scoped>
.organize-node {
  .dept-row {
    display: flex;
    align-items: center;
    padding: 8px 12px;
    cursor: pointer;
    font-size: 14px;
    color: #333;
    transition: all 0.2s;

    &:hover {
      background: #f5f5f5;
    }

    .expand-btn {
      width: 20px;
      height: 20px;
      display: flex;
      align-items: center;
      justify-content: center;
      margin-right: 4px;
      cursor: pointer;
      border-radius: 2px;
      color: #999;
      transition: all 0.2s;

      &:hover {
        background: #e8e8e8;
      }

      &.expanded {
        color: #666;
      }
    }

    .expand-placeholder {
      width: 20px;
      margin-right: 4px;
    }

    .dept-icon {
      margin-right: 6px;
      font-size: 16px;
    }

    .dept-name {
      font-weight: 500;
      flex: 1;
      overflow: hidden;
      text-overflow: ellipsis;
      white-space: nowrap;
    }
  }

  .dept-children {
    .user-row {
      display: flex;
      align-items: center;
      padding: 8px 12px;
      cursor: pointer;
      font-size: 13px;
      color: #333;
      transition: all 0.2s;

      &:hover {
        background: #f5f5f5;

        .chat-btn {
          opacity: 1;
        }
      }

      .user-avatar {
        margin-right: 10px;
        flex-shrink: 0;
      }

      .user-info {
        flex: 1;
        display: flex;
        flex-direction: column;
        gap: 2px;
        min-width: 0;
        overflow: hidden;

        .user-name {
          display: flex;
          align-items: center;
          gap: 4px;
          font-weight: 500;
          overflow: hidden;
          text-overflow: ellipsis;
          white-space: nowrap;
        }

        .user-position {
          font-size: 11px;
          color: #999;
          overflow: hidden;
          text-overflow: ellipsis;
          white-space: nowrap;
        }
      }

      .chat-btn {
        padding: 2px 8px;
        font-size: 12px;
        color: #1890ff;
        border: 1px solid #1890ff;
        border-radius: 4px;
        opacity: 0;
        transition: all 0.2s;
        flex-shrink: 0;

        &:hover {
          background: #1890ff;
          color: #fff;
        }
      }
    }
  }
}
</style>
