# 主题皮肤系统实现文档

## 概述

根据参考图片设计并实现了一套可配置的主题皮肤系统，包含两种主题：

1. **华夏红** (原浅色主题) - 主色调 `#BF0008`
2. **浅灰** (新主题) - 主色调 `#5B6B79`

## 主题配置参数

### 1. 颜色系统

| 参数 | 华夏红 | 浅灰 | 说明 |
|------|--------|------|------|
| `primary` | `#BF0008` | `#5B6B79` | 主色调 |
| `primaryHover` | `#D41820` | `#6B7B89` | 悬停色 |
| `primaryPressed` | `#A00006` | `#4B5B69` | 按下色 |
| `bgColor` | `#ffffff` | `#F8F9FA` | 背景色 |
| `textPrimary` | `#333333` | `#1a1a2e` | 主要文字 |
| `textSecondary` | `#666666` | `#4a5568` | 次要文字 |

### 2. 导航栏

| 参数 | 华夏红 | 浅灰 |
|------|--------|------|
| `navBg` | `#BF0008` | `#F8F9FA` |
| `navText` | `#ffffff` | `#4a5568` |
| `navIcon` | `#ffffff` | `#5B6B79` |

### 3. 消息列表

| 参数 | 华夏红 | 浅灰 |
|------|--------|------|
| `messageItemBg` | `#ffffff` | `#ffffff` |
| `messageItemHover` | `#f5f5f5` | `#F8F9FA` |
| `messageItemActive` | `rgba(191,0,8,0.08)` | `rgba(91,107,121,0.08)` |
| `badgeBg` | `#BF0008` | `#5B6B79` |

### 4. 消息气泡

| 参数 | 华夏红 | 浅灰 |
|------|--------|------|
| `bubbleLeftBg` | `#f5f5f5` | `#ffffff` |
| `bubbleRightBg` | `#BF0008` | `#5B6B79` |
| `bubbleRightText` | `#ffffff` | `#ffffff` |

### 5. 组织架构

| 参数 | 华夏红 | 浅灰 |
|------|--------|------|
| `orgTreeBg` | `#fafafa` | `#F8F9FA` |
| `orgTreeIcon` | `#BF0008` | `#5B6B79` |
| `orgTreeItemActive` | `rgba(191,0,8,0.08)` | `rgba(91,107,121,0.1)` |

### 6. 人员卡片

| 参数 | 华夏红 | 浅灰 |
|------|--------|------|
| `cardBg` | `#ffffff` | `#ffffff` |
| `cardBorder` | `#e8e8e8` | `#E2E8F0` |
| `cardName` | `#333333` | `#1a1a2e` |
| `cardPosition` | `#666666` | `#4a5568` |

## 文件变更

### 核心配置文件

| 文件 | 变更 |
|------|------|
| `src/constant/theme.ts` | 新增主题配置对象和 Naive UI 覆盖 |
| `src/assets/css/define/theme.less` | 新增 CSS 变量定义 |
| `src/hooks/useThemeMode.ts` | 更新主题切换逻辑 |
| `src/store/modules/settings.ts` | 默认主题改为华夏红 |

### 组件更新

| 文件 | 变更 |
|------|------|
| `src/layout/MainLayout.vue` | 使用主题变量 |
| `src/layout/component/Menu.vue` | 导航栏主题适配 |
| `src/views/setting/personalize.vue` | 主题选择界面 |
| `src/views/message/sider/TalkItem.vue` | 消息列表主题 |
| `src/views/message/panel/Header.vue` | 聊天头部主题 |
| `src/views/contact/organize.vue` | 组织架构主题 |
| `src/components/mechat/component/TextMessage.vue` | 消息气泡主题 |

## 使用方法

### 在组件中使用主题

```vue
<script setup>
import { useThemeMode } from '@/hooks'

const { currentTheme } = useThemeMode()
</script>

<template>
  <div :style="{ backgroundColor: currentTheme.primary }">
    主题颜色
  </div>
</template>
```

### CSS 变量使用

```css
.my-component {
  background-color: var(--im-primary-color);
  color: var(--im-text-color);
}
```

### 切换主题

```typescript
import { useThemeSwitcher } from '@/hooks'

const { switchTheme, themes } = useThemeSwitcher()

// 切换到浅灰主题
switchTheme('light-gray')

// 切换到华夏红主题
switchTheme('huaxia-red')
```

## 主题切换位置

设置 → 个性设置 → 主题皮肤

提供可视化主题预览卡片，点击即可切换。

## 扩展新主题

1. 在 `src/constant/theme.ts` 中添加新主题配置对象
2. 在 `src/assets/css/define/theme.less` 中添加对应的 CSS 变量
3. 在 `useThemeSwitcher` 的 `themes` 数组中添加新主题选项
