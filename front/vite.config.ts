import { defineConfig, loadEnv } from 'vite'
import { fileURLToPath, URL } from 'node:url'
import vue from '@vitejs/plugin-vue'
import vueJsx from '@vitejs/plugin-vue-jsx'
import compressPlugin from 'vite-plugin-compression'
import AutoImport from 'unplugin-auto-import/vite'
import { NaiveUiResolver } from 'unplugin-vue-components/resolvers'
import Components from 'unplugin-vue-components/vite'
import path from 'node:path'

// https://vitejs.dev/config/
export default defineConfig(({ mode }) => {
  // 根据当前工作目录中的 `mode` 加载 .env 文件
  const env = loadEnv(mode, process.cwd(), 'VITE')

  const isElectron = mode === 'electron'
  const isDev = mode === 'development'

  // Electron 模式使用相对路径，hash 路由模式下需要 './'
  const basePath = isElectron ? './' : (env.VITE_BASE || '/')

  return {
    base: basePath,
    resolve: {
      alias: {
        '@': fileURLToPath(new URL('./src', import.meta.url))
      },
      extensions: ['.js', '.json', 'jsx', '.vue', '.ts']
    },
    root: process.cwd(),
    assetsInclude: ['./src/assets'],
    plugins: [
      vue(),
      vueJsx({}),
      compressPlugin({
        threshold: 1024 * 1024 * 1
      }),
      AutoImport({
        imports: ['vue', 'vue-router', 'pinia'],
        dts: './auto-imports.d.ts'
      }),
      Components({
        dts: true,
        dirs: [],
        resolvers: [NaiveUiResolver()]
      })
    ],
    define: {
      __APP_ENV__: env.APP_ENV
    },
    build: {
      emptyOutDir: true,
      chunkSizeWarningLimit: 1000,
      // Electron 构建优化
      rollupOptions: {
        output: {
          // 手动分包
          manualChunks: isElectron
            ? {
                'vendor-vue': ['vue', 'vue-router', 'pinia'],
                'vendor-ui': ['naive-ui'],
                'vendor-media': ['xgplayer', 'js-audio-recorder'],
                'vendor-utils': ['crypto-js', 'dayjs', 'uuid', 'jsencrypt']
              }
            : undefined
        }
      }
    },
    // 开发服务器配置
    server: {
      port: isDev ? 5173 : undefined,
      proxy: isDev
        ? {
            '/api': {
              target: 'http://localhost:9501',
              changeOrigin: true
            }
          }
        : undefined
    },
    // 路径别名
    css: {
      preprocessorOptions: {
        less: {
          javascriptEnabled: true
        }
      }
    }
  }
})
