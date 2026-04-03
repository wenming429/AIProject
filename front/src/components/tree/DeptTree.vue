<script setup lang="ts">
import { useThemeMode } from '@/hooks'
import TreeNode from './TreeNode.vue'

const { currentTheme } = useThemeMode()

const props = defineProps<{
  data: any[]
  defaultExpandedKeys?: number[]
  defaultSelectedKeys?: number[]
}>()

const emit = defineEmits<{
  select: [key: number, item: any]
}>()

// 展开的节点
const expandedKeys = ref<number[]>(props.defaultExpandedKeys || [])
// 选中的节点
const selectedKey = ref<number | null>(props.defaultSelectedKeys?.[0] || null)

// 切换展开/折叠
const toggleExpand = (item: any, e: Event) => {
  e.stopPropagation()
  const index = expandedKeys.value.indexOf(item.dept_id)
  if (index > -1) {
    expandedKeys.value.splice(index, 1)
  } else {
    expandedKeys.value.push(item.dept_id)
  }
}

// 选择节点
const selectNode = (item: any) => {
  selectedKey.value = item.dept_id
  emit('select', item.dept_id, item)
}
</script>

<template>
  <div 
    class="dept-tree"
    :style="{
      '--tree-icon': currentTheme.orgTreeIcon,
      '--tree-text': currentTheme.orgTreeText,
      '--tree-hover': currentTheme.orgTreeItemHover,
      '--tree-active': currentTheme.orgTreeItemActive,
      '--tree-bg': currentTheme.orgTreeBg,
      '--tree-primary': currentTheme.primary
    }"
  >
    <TreeNode
      v-for="item in data"
      :key="item.dept_id"
      :item="item"
      :expandedKeys="expandedKeys"
      :selectedKey="selectedKey"
      @toggle="toggleExpand"
      @select="selectNode"
    />
  </div>
</template>

<style lang="less" scoped>
.dept-tree {
  font-size: 14px;
  user-select: none;
}
</style>
