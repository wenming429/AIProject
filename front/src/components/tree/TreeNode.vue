<script setup lang="ts">
import { Right, DownOne, FolderOpen, FolderClose, Peoples } from '@icon-park/vue-next'

interface Props {
  item: any
  expandedKeys: number[]
  selectedKey: number | null
  level?: number
  maxLevel?: number  // 最大显示层级
}

const props = withDefaults(defineProps<Props>(), {
  level: 0,
  maxLevel: 4  // 默认最多显示4层
})

const emit = defineEmits<{
  toggle: [item: any, event: Event]
  select: [item: any]
}>()

const isExpanded = computed(() => props.expandedKeys.includes(props.item.dept_id))
const isSelected = computed(() => props.selectedKey === props.item.dept_id)
const hasChildren = computed(() => props.item.children && props.item.children.length > 0)

// 层级深度超过限制时强制折叠
const shouldAutoCollapse = computed(() => props.level >= props.maxLevel)

// 计算缩进（根据层级动态调整）
const paddingLeft = computed(() => {
  const basePadding = 12
  const levelPadding = Math.min(props.level, props.maxLevel) * 12
  return `${basePadding + levelPadding}px`
})

// 根据层级动态调整字体大小和间距
const nodeStyle = computed(() => {
  const baseFontSize = 13
  const minFontSize = 11
  const fontSize = Math.max(minFontSize, baseFontSize - props.level * 0.5)
  
  return {
    fontSize: `${fontSize}px`,
    padding: props.level > 2 ? '4px 8px' : '6px 10px'
  }
})

const onToggle = (e: Event) => {
  e.stopPropagation()
  emit('toggle', props.item, e)
}

const onSelect = () => {
  emit('select', props.item)
}
</script>

<template>
  <div class="tree-node">
    <div 
      class="tree-node-content"
      :class="{ 
        expanded: isExpanded, 
        selected: isSelected,
        'has-children': hasChildren,
        'auto-collapsed': shouldAutoCollapse
      }"
      :style="{ paddingLeft: paddingLeft, ...nodeStyle }"
      @click="onSelect"
    >
      <!-- 展开/折叠图标 -->
      <span 
        v-if="hasChildren"
        class="expand-icon"
        @click.stop="onToggle"
      >
        <n-icon 
          :component="isExpanded ? DownOne : Right" 
          :size="14"
          class="arrow-icon"
        />
      </span>
      <span v-else class="expand-placeholder"></span>
      
      <!-- 文件夹图标 -->
      <span class="folder-icon">
        <n-icon 
          :component="hasChildren 
            ? (isExpanded ? FolderOpen : FolderClose) 
            : Peoples" 
          :size="16"
        />
      </span>
      
      <!-- 节点文本 -->
      <span class="node-label" :class="{ 'compact-text': level > 2 }">
        {{ item.dept_name || item.label }}
      </span>
      
      <!-- 人数 -->
      <span v-if="item.count || item.suffix" class="node-count">
        ({{ item.count || item.suffix }})
      </span>
    </div>
    
    <!-- 子节点 -->
    <div 
      v-if="hasChildren && isExpanded" 
      class="tree-children"
    >
      <TreeNode
        v-for="child in item.children"
        :key="child.dept_id"
        :item="child"
        :expandedKeys="expandedKeys"
        :selectedKey="selectedKey"
        :level="level + 1"
        :max-level="maxLevel"
        @toggle="(item, e) => $emit('toggle', item, e)"
        @select="(item) => $emit('select', item)"
      />
    </div>
  </div>
</template>

<style lang="less" scoped>
.tree-node {
  .tree-node-content {
    display: flex;
    align-items: center;
    padding: 6px 10px;
    cursor: pointer;
    border-radius: 6px;
    margin: 2px 4px;
    transition: all 0.2s ease;
    color: var(--tree-text, #333);

    &:hover {
      background-color: var(--tree-hover, #f5f5f5);
    }

    &.selected:hover {
      background: linear-gradient(90deg, var(--tree-active, #ffe6e6) 0%, rgba(255,255,255,0.5) 100%);
    }

    &.selected {
      background: linear-gradient(90deg, var(--tree-active, #ffe6e6) 0%, rgba(255,255,255,0.3) 100%);
      color: var(--tree-primary, #BF0008);
      font-weight: 500;
      border-radius: 6px;

      .folder-icon {
        color: var(--tree-primary, #BF0008);
      }

      .node-count {
        color: var(--tree-primary, #BF0008);
        opacity: 0.8;
      }
    }

    // 深层级自动折叠样式
    &.auto-collapsed {
      opacity: 0.85;
      
      .node-label {
        font-size: 11px;
      }
    }

    // 紧凑文本样式
    .compact-text {
      font-size: 11px !important;
      letter-spacing: -0.3px;
    }

    // 展开/折叠图标
    .expand-icon {
      width: 18px;
      height: 18px;
      min-width: 18px;
      display: flex;
      align-items: center;
      justify-content: center;
      margin-right: 4px;
      border-radius: 4px;
      transition: all 0.2s;
      cursor: pointer;

      &:hover {
        background-color: rgba(128, 128, 128, 0.15);
      }

      .arrow-icon {
        transition: transform 0.2s ease;
        color: var(--tree-text, #666);
        opacity: 0.7;
      }
    }

    &.expanded {
      .expand-icon .arrow-icon {
        transform: rotate(0deg);
      }
    }

    .expand-placeholder {
      width: 18px;
      min-width: 18px;
      margin-right: 4px;
    }

    // 文件夹图标
    .folder-icon {
      width: 18px;
      height: 18px;
      min-width: 18px;
      display: flex;
      align-items: center;
      justify-content: center;
      margin-right: 4px;
      color: var(--tree-icon, #666);
      opacity: 0.85;
      transition: all 0.2s;
    }

    // 节点文本
    .node-label {
      flex: 1;
      overflow: hidden;
      text-overflow: ellipsis;
      white-space: nowrap;
      font-size: 13px;
      letter-spacing: 0;
    }

    // 人数
    .node-count {
      font-size: 11px;
      color: inherit;
      opacity: 0.6;
      margin-left: 4px;
      min-width: 24px;
    }
  }

  .tree-children {
    position: relative;
  }
}
</style>
