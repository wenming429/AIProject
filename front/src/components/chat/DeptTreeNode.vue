<script lang="ts" setup>
import { computed } from 'vue'
import { Right, DownOne } from '@icon-park/vue-next'

const props = defineProps<{
  dept: any
  expandedKeys: number[]
  selectedDeptId: number | null
  level?: number
  userCountFn: (dept: any) => number
}>()

const emit = defineEmits<{
  toggleExpand: [dept: any, event: Event]
  selectDept: [dept: any]
}>()

// 是否展开
const isExpanded = computed(() => {
  return props.expandedKeys.includes(props.dept.dept_id)
})

// 是否选中
const isSelected = computed(() => {
  return props.selectedDeptId === props.dept.dept_id
})

// 是否有子部门
const hasChildren = computed(() => {
  return props.dept.children?.length > 0
})

// 人员数量
const userCount = computed(() => {
  return props.userCountFn(props.dept)
})

// 切换展开
function onToggleExpand(e: Event) {
  emit('toggleExpand', props.dept, e)
}

// 选择部门
function onSelectDept() {
  emit('selectDept', props.dept)
}
</script>

<template>
  <div class="dept-tree-node" :style="{ paddingLeft: `${(level || 0) * 12}px` }">
    <!-- 部门项 -->
    <div
      class="dept-item"
      :class="{ selected: isSelected }"
      @click="onSelectDept"
    >
      <!-- 展开/收起按钮 -->
      <span
        v-if="hasChildren"
        class="expand-btn"
        :class="{ expanded: isExpanded }"
        @click.stop="onToggleExpand($event)"
      >
        <n-icon :component="isExpanded ? DownOne : Right" theme="filled" size="12" />
      </span>
      <span v-else class="expand-placeholder"></span>

      <!-- 文件夹图标 -->
      <span class="folder-icon">📁</span>

      <!-- 部门名称 -->
      <span class="dept-name">{{ dept.dept_name }}</span>

      <!-- 人员数量 -->
      <span v-if="userCount > 0" class="dept-count">{{ userCount }}</span>
    </div>

    <!-- 子部门 -->
    <div v-if="hasChildren && isExpanded" class="children-container">
      <DeptTreeNode
        v-for="child in dept.children"
        :key="child.dept_id"
        :dept="child"
        :expanded-keys="expandedKeys"
        :selected-dept-id="selectedDeptId"
        :level="(level || 0) + 1"
        :user-count-fn="userCountFn"
        @toggle-expand="(d, e) => $emit('toggleExpand', d, e)"
        @select-dept="(d) => $emit('selectDept', d)"
      />
    </div>
  </div>
</template>

<style lang="less" scoped>
.dept-tree-node {
  .dept-item {
    display: flex;
    align-items: center;
    padding: 8px 12px;
    cursor: pointer;
    font-size: 13px;
    color: #333;
    transition: all 0.2s;
    border-radius: 4px;
    margin: 2px 8px;

    &:hover {
      background: #f5f5f5;
    }

    &.selected {
      background: #e6f7ff;
      color: #1890ff;

      .folder-icon {
        filter: hue-rotate(200deg);
      }

      .dept-count {
        background: #1890ff;
        color: #fff;
      }
    }

    .expand-btn {
      width: 18px;
      height: 18px;
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
    }

    .expand-placeholder {
      width: 18px;
      margin-right: 4px;
    }

    .folder-icon {
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
      background: #f0f0f0;
      padding: 0 6px;
      border-radius: 10px;
      min-width: 18px;
      text-align: center;
      margin-left: 4px;
    }
  }
}
</style>
