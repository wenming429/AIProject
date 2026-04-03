<script lang="ts" setup>
import { useSettingsStore, presetCardThemes } from '@/store'
import { useInject, useThemeSwitcher } from '@/hooks'
import { Check, Refresh } from '@icon-park/vue-next'

const settingsStore = useSettingsStore()
const { switchTheme, themes } = useThemeSwitcher()
const { message } = useInject()

// 当前主题
const currentTheme = computed({
  get: () => settingsStore.themeMode,
  set: (value: string) => {
    switchTheme(value)
  }
})

// 名片背景设置
const showCardThemeModal = ref(false)
const customColor = ref('#BF0008')
const selectedPreset = ref('')

// 打开名片主题设置
const openCardThemeSetting = () => {
  customColor.value = settingsStore.cardThemeColor || '#BF0008'
  selectedPreset.value = settingsStore.cardThemeColor
  showCardThemeModal.value = true
}

// 选择预设主题
const selectPreset = (preset: typeof presetCardThemes[0]) => {
  selectedPreset.value = preset.color
  customColor.value = preset.color
  settingsStore.setCardTheme(preset.color, preset.gradient)
  message.success(`已应用${preset.name}主题`)
}

// 应用自定义颜色
const applyCustomColor = () => {
  const gradient = `linear-gradient(135deg, ${customColor.value} 0%, ${lightenColor(customColor.value, 20)} 100%)`
  settingsStore.setCardTheme(customColor.value, gradient)
  selectedPreset.value = customColor.value
  message.success('已应用自定义主题色')
}

// 重置为默认
const resetToDefault = () => {
  settingsStore.resetCardTheme()
  selectedPreset.value = ''
  customColor.value = '#BF0008'
  message.success('已恢复默认主题')
}

// 颜色变亮辅助函数
const lightenColor = (color: string, percent: number): string => {
  const num = parseInt(color.replace('#', ''), 16)
  const amt = Math.round(2.55 * percent)
  const R = (num >> 16) + amt
  const G = ((num >> 8) & 0x00ff) + amt
  const B = (num & 0x0000ff) + amt
  return '#' + (
    0x1000000 +
    (R < 255 ? (R < 1 ? 0 : R) : 255) * 0x10000 +
    (G < 255 ? (G < 1 ? 0 : G) : 255) * 0x100 +
    (B < 255 ? (B < 1 ? 0 : B) : 255)
  ).toString(16).slice(1)
}

// 获取当前名片背景描述
const cardThemeDesc = computed(() => {
  if (!settingsStore.useCustomCardTheme) {
    return '跟随系统主题色'
  }
  const preset = presetCardThemes.find(p => p.color === settingsStore.cardThemeColor)
  return preset ? preset.name : '自定义主题色'
})
</script>

<template>
  <section>
    <h3 class="title">个性设置</h3>

    <div class="view-box">
      <!-- 主题皮肤设置 -->
      <div class="view-list" style="height: 200px; flex-direction: column; align-items: flex-end; padding: 16px 0;">
        <div class="content" style="width: 100%;">
          <div class="name">主题皮肤</div>
          <div class="desc">选择您喜欢的界面配色风格</div>
        </div>
        <div class="tools" style="width: 100%; min-width: auto; justify-content: flex-end;">
          <div
            v-for="theme in themes"
            :key="theme.key"
            class="theme-card"
            :class="{ active: currentTheme === theme.key }"
            @click="currentTheme = theme.key"
          >
            <div 
              class="theme-preview" 
              :style="{ 
                background: theme.color,
                '--preview-primary': theme.color
              }"
            >
              <div class="preview-nav"></div>
              <div class="preview-content">
                <div class="preview-sidebar"></div>
                <div class="preview-main">
                  <div class="preview-message"></div>
                  <div class="preview-message preview-message-accent"></div>
                </div>
              </div>
            </div>
            <div class="theme-name">{{ theme.name }}</div>
            <div class="theme-check" v-if="currentTheme === theme.key">
              <n-icon :component="Check" />
            </div>
          </div>
        </div>
      </div>

      <!-- 我的名片背景设置 -->
      <div class="view-list">
        <div class="content">
          <div class="name">我的名片背景</div>
          <div class="desc">{{ cardThemeDesc }}</div>
        </div>
        <div class="tools">
          <div class="card-theme-preview" 
               :style="{ background: settingsStore.getCardBackground('#BF0008') }"
               @click="openCardThemeSetting">
          </div>
          <n-button type="primary" text @click="openCardThemeSetting"> 修改 </n-button>
        </div>
      </div>

      <div class="view-list">
        <div class="content">
          <div class="name">聊天背景</div>
          <div class="desc">当前未设置聊天背景图</div>
        </div>
        <div class="tools">
          <n-button type="primary" text> 修改 </n-button>
        </div>
      </div>
    </div>

    <!-- 名片主题色设置弹窗 -->
    <n-modal
      v-model:show="showCardThemeModal"
      title="设置名片背景主题色"
      preset="card"
      style="width: 500px; max-width: 90vw"
      :mask-closable="false"
    >
      <div class="card-theme-modal">
        <!-- 实时预览 -->
        <div class="preview-section">
          <div class="preview-label">实时预览</div>
          <div class="card-preview" :style="{ background: settingsStore.getCardBackground('#BF0008') }">
            <div class="preview-avatar"></div>
            <div class="preview-name">我的昵称</div>
            <div class="preview-pattern"></div>
          </div>
        </div>

        <!-- 预设主题色 -->
        <div class="preset-section">
          <div class="section-title">预设主题</div>
          <div class="preset-grid">
            <div
              v-for="preset in presetCardThemes"
              :key="preset.color"
              class="preset-item"
              :class="{ active: selectedPreset === preset.color }"
              @click="selectPreset(preset)"
            >
              <div class="preset-color" :style="{ background: preset.gradient }"></div>
              <div class="preset-name">{{ preset.name }}</div>
              <div class="preset-check" v-if="selectedPreset === preset.color">
                <n-icon :component="Check" />
              </div>
            </div>
          </div>
        </div>

        <!-- 自定义颜色 -->
        <div class="custom-section">
          <div class="section-title">自定义颜色</div>
          <div class="custom-color-picker">
            <n-color-picker
              v-model:value="customColor"
              :show-alpha="false"
              :modes="['hex']"
              style="width: 200px"
            />
            <n-button type="primary" size="small" @click="applyCustomColor">
              应用
            </n-button>
          </div>
        </div>

        <!-- 操作按钮 -->
        <div class="modal-actions">
          <n-button @click="resetToDefault">
            <template #icon>
              <n-icon :component="Refresh" />
            </template>
            恢复默认
          </n-button>
          <n-button type="primary" @click="showCardThemeModal = false">
            完成
          </n-button>
        </div>
      </div>
    </n-modal>
  </section>
</template>

<style lang="less" scoped>
@import '@/assets/css/settting.less';

.theme-selector {
  display: flex;
  flex-direction: row;
  flex-wrap: nowrap;
  gap: 20px;
  width: auto;
  overflow-x: auto;
  padding-bottom: 4px;
  justify-content: flex-end;
}

.theme-card {
  position: relative;
  cursor: pointer;
  border-radius: 12px;
  padding: 8px;
  border: 2px solid transparent;
  transition: all 0.3s;
  background: var(--im-bg-secondary);
  flex: 0 0 auto;
  min-width: 136px;
  
  &:hover {
    border-color: var(--border-color);
    transform: translateY(-2px);
    box-shadow: 0 4px 12px rgba(0, 0, 0, 0.08);
  }
  
  &.active {
    border-color: var(--im-primary-color);
    box-shadow: 0 4px 16px rgba(0, 0, 0, 0.12);
  }
}

.theme-preview {
  width: 120px;
  height: 90px;
  border-radius: 8px;
  overflow: hidden;
  display: flex;
  flex-direction: column;
  
  .preview-nav {
    height: 16px;
    background: rgba(255, 255, 255, 0.2);
  }
  
  .preview-content {
    flex: 1;
    display: flex;
    background: rgba(255, 255, 255, 0.95);
    
    .preview-sidebar {
      width: 30px;
      background: rgba(0, 0, 0, 0.05);
      border-right: 1px solid rgba(0, 0, 0, 0.08);
    }
    
    .preview-main {
      flex: 1;
      padding: 8px;
      display: flex;
      flex-direction: column;
      gap: 6px;
      
      .preview-message {
        height: 14px;
        border-radius: 4px;
        background: rgba(0, 0, 0, 0.08);
        
        &.preview-message-accent {
          width: 70%;
          background: var(--preview-primary, var(--im-primary-color));
          opacity: 0.8;
        }
      }
    }
  }
}

.theme-name {
  text-align: center;
  margin-top: 10px;
  font-size: 14px;
  color: var(--im-text-color);
  font-weight: 500;
}

.theme-check {
  position: absolute;
  top: 4px;
  right: 4px;
  width: 20px;
  height: 20px;
  border-radius: 50%;
  background: var(--im-primary-color);
  color: white;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 12px;
}

// 名片主题预览
.card-theme-preview {
  width: 40px;
  height: 40px;
  border-radius: 8px;
  margin-right: 12px;
  cursor: pointer;
  border: 2px solid var(--border-color);
  transition: all 0.3s;
  
  &:hover {
    transform: scale(1.1);
    border-color: var(--im-primary-color);
  }
}

// 弹窗样式
.card-theme-modal {
  padding: 8px;
}

.preview-section {
  margin-bottom: 24px;
  
  .preview-label {
    font-size: 13px;
    color: var(--im-text-secondary);
    margin-bottom: 12px;
  }
  
  .card-preview {
    width: 100%;
    height: 140px;
    border-radius: 12px;
    position: relative;
    overflow: hidden;
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    transition: background 0.3s;
    
    &::before {
      content: '';
      position: absolute;
      width: 120px;
      height: 120px;
      border-radius: 50%;
      background: linear-gradient(to right, rgba(255,255,255,0.15), rgba(255,255,255,0.05));
      right: -20%;
      top: -20%;
    }
    
    &::after {
      content: '';
      position: absolute;
      width: 100px;
      height: 100px;
      border-radius: 50%;
      background: linear-gradient(to left, rgba(255,255,255,0.1), rgba(255,255,255,0.02));
      left: -15%;
      bottom: -15%;
    }
    
    .preview-avatar {
      width: 50px;
      height: 50px;
      border-radius: 50%;
      background: rgba(255, 255, 255, 0.9);
      border: 3px solid #ffffff;
      z-index: 2;
      margin-bottom: 8px;
    }
    
    .preview-name {
      color: #ffffff;
      font-size: 14px;
      font-weight: 500;
      z-index: 2;
      text-shadow: 0 1px 2px rgba(0, 0, 0, 0.2);
    }
  }
}

.section-title {
  font-size: 14px;
  font-weight: 600;
  color: var(--im-text-color);
  margin-bottom: 12px;
}

.preset-section {
  margin-bottom: 24px;
}

.preset-grid {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: 12px;
}

.preset-item {
  position: relative;
  cursor: pointer;
  border-radius: 10px;
  padding: 6px;
  border: 2px solid transparent;
  transition: all 0.3s;
  background: var(--im-bg-secondary);
  
  &:hover {
    border-color: var(--border-color);
    transform: translateY(-2px);
  }
  
  &.active {
    border-color: var(--im-primary-color);
  }
  
  .preset-color {
    width: 100%;
    height: 50px;
    border-radius: 6px;
  }
  
  .preset-name {
    text-align: center;
    margin-top: 6px;
    font-size: 12px;
    color: var(--im-text-color);
  }
  
  .preset-check {
    position: absolute;
    top: 2px;
    right: 2px;
    width: 18px;
    height: 18px;
    border-radius: 50%;
    background: var(--im-primary-color);
    color: white;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 10px;
  }
}

.custom-section {
  margin-bottom: 24px;
  
  .custom-color-picker {
    display: flex;
    align-items: center;
    gap: 12px;
  }
}

.modal-actions {
  display: flex;
  justify-content: space-between;
  padding-top: 16px;
  border-top: 1px solid var(--border-color);
}

// 响应式适配
@media (max-width: 480px) {
  .preset-grid {
    grid-template-columns: repeat(3, 1fr);
  }
  
  .theme-selector {
    flex-wrap: nowrap;
    gap: 12px;
  }
  
  .theme-card {
    flex: 0 0 auto;
    min-width: 120px;
  }
  
  .theme-preview {
    width: 104px;
    height: 70px;
  }
}
</style>
