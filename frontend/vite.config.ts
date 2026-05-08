import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'
import Components from 'unplugin-vue-components/vite'
import { VantResolver } from '@vant/auto-import-resolver'
import { VitePWA } from 'vite-plugin-pwa'

const isNativeBuild = process.env.BUILD_TARGET === 'native'

export default defineConfig({
  plugins: [
    vue(),
    Components({
      resolvers: [VantResolver()],
    }),
    ...(isNativeBuild
      ? []
      : [
          VitePWA({
            registerType: 'autoUpdate',
            manifest: {
              name: '战队管理系统',
              short_name: '战队管理',
              description: 'RoboMaster 战队项目管理',
              theme_color: '#3b82f6',
              background_color: '#0f172a',
              display: 'standalone',
              start_url: '/',
              icons: [
                { src: '/icons/icon-192.png', sizes: '192x192', type: 'image/png' },
                { src: '/icons/icon-512.png', sizes: '512x512', type: 'image/png' },
                { src: '/icons/icon-512.png', sizes: '512x512', type: 'image/png', purpose: 'maskable' },
              ],
            },
            workbox: {
              globPatterns: ['**/*.{js,css,html,ico,png,svg,woff2}'],
              runtimeCaching: [
                {
                  urlPattern: /^\/api\//,
                  handler: 'NetworkFirst',
                  options: { cacheName: 'api-cache', expiration: { maxEntries: 50, maxAgeSeconds: 300 } },
                },
              ],
            },
          }),
        ]),
  ],
  server: {
    port: 5173,
    proxy: {
      '/api': {
        target: 'http://localhost:3000',
        changeOrigin: true,
      },
    },
  },
})
