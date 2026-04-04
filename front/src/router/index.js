import MainLayout from '@/layout/MainLayout.vue'
import { isLogin } from '@/utils/auth.ts'
import { createRouter, createWebHashHistory, createWebHistory } from 'vue-router'

import AuthRouter from './modules/auth.js'
import ContactRouter from './modules/contact.js'
import SettingRouter from './modules/setting.js'

const routes = [
  {
    path: '/',
    name: 'home',
    meta: { auth: true },
    component: MainLayout,
    redirect: '/message',
    children: [
      {
        path: 'message',
        name: 'message',
        meta: { auth: true },
        component: () => import('@/views/message/index.vue')
      },
      {
        path: 'note',
        name: 'note',
        meta: { auth: true },
        component: () => import('@/views/note/index.vue')
      },
      {
        path: 'example',
        name: 'example',
        meta: { auth: false },
        component: () => import('@/views/example/index.vue')
      },
      SettingRouter,
      ContactRouter
    ]
  },

  {
    path: '/embed',
    name: 'embed',
    meta: { auth: true },
    component: () => import('@/views/embed/index.vue')
  },
  AuthRouter,
  {
    path: '/oauth/callback/:oauth_type',
    meta: { auth: false },
    component: () => import('@/views/auth/oauth.vue')
  },
  {
    path: '/:pathMatch(.*)*',
    name: '404 NotFound',
    component: () => import('@/views/other/not-found.vue')
  }
]

/**
 * 获取路由历史模式
 * Electron 打包后使用 file:// 协议，必须使用 hash 模式
 * 检测逻辑：
 * 1. VITE_ROUTER_MODE=hash 强制使用 hash
 * 2. 检测是否在 Electron 环境中（window.$electron 存在）
 * 3. 其他情况使用配置的模式
 */
const getHistoryMode = () => {
  // Electron 环境强制使用 hash 路由
  const isElectron = typeof window !== 'undefined' && window.$electron !== undefined
  const routerMode = import.meta.env.VITE_ROUTER_MODE

  // 优先使用环境变量设置
  if (routerMode === 'hash' || isElectron) {
    return createWebHashHistory()
  }
  // 使用配置的 history 模式
  return createWebHistory()
}

const router = createRouter({
  history: getHistoryMode(),
  routes,
  strict: true,
  scrollBehavior: () => ({ left: 0, top: 0 })
})

// 设置中间件，权限验证
router.beforeEach((to) => {
  const login = isLogin()

  if (to.meta?.auth && !login) {
    return {
      path: '/auth/login',
      query: { redirect: to.fullPath }
    }
  }

  if (['/auth/login'].includes(to.path) && login) {
    return { path: '/' }
  }
})

export default router
