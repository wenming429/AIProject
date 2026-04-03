<script setup lang="ts">
import { fetchOrganizeDepartmentList, fetchOrganizePersonnelList } from '@/apis/api'
import { fetchApi } from '@/apis/request'
import { useInject, useThemeMode } from '@/hooks'
import { useTalkStore, useUserStore } from '@/store'
import { Female, Male, Search, ChartGraph, Peoples } from '@icon-park/vue-next'
import DeptTree from '@/components/tree/DeptTree.vue'
import { NTag } from 'naive-ui'

const router = useRouter()
const userStore = useUserStore()
const talkStore = useTalkStore()
const { toShowUserInfo, message } = useInject()
const { currentTheme } = useThemeMode()

const ancestors = ref('')
const keywords = ref('')
const items = ref<any[]>([])

const filter = computed(() => {
  return items.value.filter((item) => {
    return (
      item.nickname?.match(keywords.value) != null &&
      (ancestors.value == '' || item.ancestors.indexOf(ancestors.value) > -1)
    )
  })
})

const tree = ref<any[]>([])
const breadcrumb = ref<
  {
    name: string
    dept_id: number
  }[]
>([{ name: '企业成员', dept_id: -1 }])

const onToTalk = (item: any) => {
  if (userStore.uid != item.user_id) {
    talkStore.toTalk(1, item.user_id, router)
  } else {
    message.info('禁止给自己发送消息!')
  }
}

function toTree(list: any[]): any[] {
  const map = {}

  list.forEach((item: any) => {
    map[item.dept_id] = item
  })

  const ancestors = (value: string) => {
    const list: string[] = []

    value.split(',').forEach((id) => {
      const item = map[parseInt(id)] as any

      item && list.push(item.dept_name)
    })

    return list
  }

  const tree: any[] = []

  for (const item of list) {
    item.breadcrumb = ancestors(item.ancestors || '').join(' / ')

    const parent = map[item.parent_id]
    if (parent) {
      if (parent.children == undefined) parent.children = []
      parent.children.push(item)
    } else {
      tree.push(item)
    }
  }

  return tree
}

const onInfo = (item: any) => {
  toShowUserInfo(item.user_id)
}

// 选择部门
const onDeptSelect = (deptId: number, item: any) => {
  if (item.breadcrumb == '') {
    breadcrumb.value = [{ name: '企业成员', dept_id: -1 }]
  } else {
    breadcrumb.value = item.breadcrumb.split('/').map((name: any) => {
      return {
        name: name,
        dept_id: item.dept_id
      }
    })
  }

  ancestors.value = item.ancestors
}

const tag = () => {
  return h(NTag, {
    type: 'info',
    size: 'small',
    bordered: false,
    style: {
      margin: '5px 0px 5px 0px'
    },
    innerHTML: '全员'
  })
}

async function onLoadDepartment() {
  const [err, data] = await fetchApi(fetchOrganizeDepartmentList, {})
  if (err) return

  tree.value = toTree(
    data.items.map((item: any) => {
      return {
        parent_id: item.parent_id,
        dept_id: item.dept_id,
        dept_name: item.dept_name,
        ancestors: item.dept_id > 0 ? `${item.ancestors},${item.dept_id}` : '',
        prefix: item.dept_id == -1 ? tag : null,
        suffix: item.count
      }
    })
  )
}

async function onLoadData() {
  const [err, data] = await fetchApi(fetchOrganizePersonnelList, {})
  if (err) return

  const users = data.items || []

  users.map((item: any) => {
    item.position_items.sort((a, b) => a.sort - b.sort)
    item.ancestors = `${item.dept_item.ancestors},${item.dept_item.dept_id}`

    item.position = item.position_items.map((item: any) => item.name).join('、')

    return item
  })

  items.value = users.sort((a, b) => a.nickname.localeCompare(b.nickname, 'zh-CN'))
}

onMounted(() => {
  onLoadData()
  onLoadDepartment()
})
</script>

<template>
  <section 
    class="el-container is-vertical h-full organize-container"
    :style="{
      '--org-bg': currentTheme.orgTreeBg,
      '--org-text': currentTheme.orgTreeText,
      '--org-icon': currentTheme.orgTreeIcon,
      '--org-hover': currentTheme.orgTreeItemHover,
      '--org-active': currentTheme.orgTreeItemActive,
      '--card-bg': currentTheme.cardBg,
      '--card-border': currentTheme.cardBorder,
      '--card-hover': currentTheme.cardHover,
      '--card-name': currentTheme.cardName,
      '--card-position': currentTheme.cardPosition,
      '--card-dept': currentTheme.cardDept,
      '--btn-primary': currentTheme.buttonPrimaryBg,
      '--btn-primary-text': currentTheme.buttonPrimaryText
    }"
  >
    <header class="el-header me-view-header border-bottom organize-header">
      <div class="breadcrumb-section">
        <n-icon :component="ChartGraph" class="org-icon" />
        <n-breadcrumb>
          <n-breadcrumb-item :clickable="false" :key="item.name" v-for="item in breadcrumb">{{
            item.name
          }}</n-breadcrumb-item>
        </n-breadcrumb>
        <span class="member-count">({{ filter.length }}人)</span>
      </div>

      <div class="search-section">
        <n-space style="display: flex; align-items: center">
          <n-input
            v-model:value.trim="keywords"
            placeholder="搜索成员"
            clearable
            style="width: 200px"
            round
          >
            <template #prefix>
              <n-icon :component="Search" />
            </template>
          </n-input>
        </n-space>
      </div>
    </header>

    <main class="el-main organize-main">
      <section class="el-container h-full">
        <aside
          class="el-aside aside"
          style="width: 220px; margin: 12px; padding: 12px"
          v-dropsize="{
            min: 200,
            max: 500,
            direction: 'right',
            key: 'aside-organize'
          }"
        >
          <div class="dept-tree-header">
            <n-icon :component="Peoples" />
            <span>组织架构</span>
          </div>
          <n-scrollbar class="tree-scroll">
            <DeptTree
              :data="tree"
              :default-expanded-keys="[-1]"
              :default-selected-keys="[-1]"
              @select="onDeptSelect"
            />
          </n-scrollbar>
        </aside>

        <main class="el-main member-main" v-if="filter.length" style="padding: 12px 12px 12px 0">
          <n-virtual-list style="max-height: inherit" :item-size="80" :items="filter">
            <template #default="{ item }">
              <div :key="item.user_id" class="item-box pointer">
                <div class="avatar" @click="onInfo(item)">
                  <im-avatar :src="item.avatar" :size="44" :username="item.nickname" />
                </div>
                <div class="content" @click="onInfo(item)">
                  <div class="content-title">
                    <span class="name">{{ item.remark || item.nickname }}</span>
                    <span class="gender-icon">
                      <n-icon v-if="item.gender == 1" :component="Male" color="#508afe" />
                      <n-icon v-if="item.gender == 2" :component="Female" color="#ff5722" />
                    </span>
                    <n-tag
                      v-for="(v, index) in item.position_items"
                      size="small"
                      type="info"
                      :key="index"
                      class="position-tag"
                      >{{ v.name }}</n-tag
                    >
                  </div>
                  <div class="content-text text-ellipsis">
                    {{ item.dept_item?.dept_name }} · {{ item.position || '暂无职位' }}
                  </div>
                </div>
                <div class="tool">
                  <n-button 
                    size="small" 
                    type="primary" 
                    class="send-msg-btn"
                    @click="onToTalk(item)"
                  >
                    发消息
                  </n-button>
                </div>
              </div>
            </template>
          </n-virtual-list>
        </main>

        <main class="el-main flex-center empty-main" v-else>
          <n-empty description="暂无相关数据" />
        </main>
      </section>
    </main>
  </section>
</template>

<style lang="less" scoped>
.organize-container {
  background-color: var(--im-bg-color);
}

.organize-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 0 16px;
  background-color: var(--im-bg-secondary);
  border-bottom: 1px solid var(--border-color);

  .breadcrumb-section {
    display: flex;
    align-items: center;
    gap: 8px;

    .org-icon {
      font-size: 18px;
      color: var(--org-icon);
    }

    .member-count {
      font-size: 13px;
      color: var(--im-text-tertiary);
      margin-left: 8px;
    }
  }

  .search-section {
    :deep(.n-input) {
      background-color: var(--im-bg-color);
    }
  }
}

.organize-main {
  background-color: var(--im-bg-color);
}

.aside {
  background-color: var(--org-bg);
  border-radius: 8px;
  border: 1px solid var(--border-color);

  .dept-tree-header {
    display: flex;
    align-items: center;
    gap: 8px;
    padding: 8px 4px 12px;
    margin-bottom: 8px;
    border-bottom: 1px solid var(--border-color);
    font-size: 14px;
    font-weight: 500;
    color: var(--org-text);

    .n-icon {
      color: var(--org-icon);
    }
  }

  .tree-scroll {
    flex: 1;
    
    :deep(.n-scrollbar-container) {
      padding-right: 4px;
    }
  }
}

.member-main {
  background-color: var(--im-bg-color);
}

.item-box {
  height: 70px;
  display: flex;
  align-items: center;
  justify-content: space-between;
  transition: all 0.3s;
  border-radius: 8px;
  padding: 10px 16px;
  background-color: var(--card-bg);
  border: 1px solid var(--card-border);
  margin-bottom: 10px;

  &:hover {
    border-color: var(--btn-primary);
    box-shadow: 0 2px 8px rgba(0, 0, 0, 0.08);
    transform: translateY(-1px);
  }

  > div {
    height: inherit;
  }

  .avatar {
    width: 60px;
    height: inherit;
    flex-shrink: 0;
    display: flex;
    align-items: center;
    justify-content: center;
    
    :deep(.avatar-wrapper) {
      transition: all 0.3s ease;
      
      &:hover {
        transform: scale(1.1);
      }
    }
  }

  .content {
    flex: 1;
    overflow: hidden;
    user-select: none;
    display: flex;
    flex-direction: column;
    justify-content: center;
    padding: 0 12px;

    &-title {
      display: flex;
      align-items: center;
      gap: 8px;
      margin-bottom: 6px;

      .name {
        font-size: 15px;
        font-weight: 500;
        color: var(--card-name);
      }

      .gender-icon {
        display: flex;
        align-items: center;
      }

      .position-tag {
        font-size: 11px;
      }
    }

    &-text {
      font-size: 13px;
      color: var(--card-dept);
      overflow: hidden;
      text-overflow: ellipsis;
      white-space: nowrap;
    }
  }

  .tool {
    width: 80px;
    flex-shrink: 0;
    display: flex;
    align-items: center;
    justify-content: flex-end;

    .send-msg-btn {
      background-color: var(--btn-primary);
      color: var(--btn-primary-text);
      border: none;
      transition: all 0.2s;

      &:hover {
        opacity: 0.9;
        transform: scale(1.02);
      }
    }
  }
}

.empty-main {
  background-color: var(--im-bg-color);
}
</style>
