<script setup lang="ts">
import { computed, ref, onMounted, onUnmounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useAuthStore } from '../../stores/auth'

const route = useRoute()
const router = useRouter()
const auth = useAuthStore()
const isMobile = ref(window.innerWidth < 900)
const sidebarCollapsed = ref(false)

function handleResize() {
  isMobile.value = window.innerWidth < 900
}

onMounted(() => window.addEventListener('resize', handleResize))
onUnmounted(() => window.removeEventListener('resize', handleResize))

const navItems = [
  { icon: 'chart-trending-o', label: '仪表盘', path: '/admin', name: 'admin-dashboard' },
  { icon: 'friends-o', label: '用户与审核', path: '/admin/users', name: 'admin-users' },
  { icon: 'cluster-o', label: '组织架构', path: '/admin/org', name: 'admin-org' },
  { icon: 'todo-list-o', label: '任务管理', path: '/admin/tasks', name: 'admin-tasks' },
  { icon: 'video-o', label: '会议管理', path: '/admin/meetings', name: 'admin-meetings' },
  { icon: 'flag-o', label: '阶段性目标', path: '/admin/objectives', name: 'admin-objectives' },
  { icon: 'location-o', label: '打卡围栏', path: '/admin/fences', name: 'admin-fences' },
]

function isActive(name: string) {
  return route.name === name
}

function goto(path: string) {
  router.push(path)
}

function exitAdmin() {
  auth.setAdminMode(false)
  router.push('/')
}

async function handleLogout() {
  await auth.logout()
  router.push('/login')
}

const roleLabel = computed(() => {
  if (auth.user?.isSuperAdmin) return '超级管理员'
  const map: Record<number, string> = { 4: '项目管理', 5: '队长', 6: '指导老师' }
  return map[auth.user?.roleLevel || 0] || '管理者'
})
</script>

<template>
  <div class="admin-layout" :class="{ mobile: isMobile }">
    <aside class="admin-sidebar" :class="{ collapsed: sidebarCollapsed }">
      <div class="brand">
        <div class="brand-icon"><van-icon name="setting-o" color="#fff" size="20" /></div>
        <span v-if="!sidebarCollapsed" class="brand-text">后台管理</span>
      </div>

      <nav class="admin-nav">
        <div
          v-for="item in navItems"
          :key="item.name"
          class="nav-item"
          :class="{ active: isActive(item.name) }"
          @click="goto(item.path)"
        >
          <van-icon :name="item.icon" size="18" />
          <span v-if="!sidebarCollapsed">{{ item.label }}</span>
        </div>
      </nav>

      <div class="sidebar-footer">
        <div
          class="collapse-btn"
          @click="sidebarCollapsed = !sidebarCollapsed"
        >
          <van-icon :name="sidebarCollapsed ? 'arrow' : 'arrow-left'" />
        </div>
      </div>
    </aside>

    <div class="admin-body">
      <header class="topbar">
        <div class="crumb">
          <span class="dot"></span>
          <span>{{ navItems.find(n => isActive(n.name))?.label || '管理后台' }}</span>
        </div>
        <div class="topbar-actions">
          <div class="user-chip">
            <div class="avatar">{{ (auth.user?.realName || 'U').charAt(0) }}</div>
            <div class="user-meta">
              <div class="name">{{ auth.user?.realName }}</div>
              <div class="role">{{ roleLabel }}</div>
            </div>
          </div>
          <van-button size="small" plain icon="revoke" @click="exitAdmin">返回普通</van-button>
          <van-button size="small" type="danger" plain @click="handleLogout">退出</van-button>
        </div>
      </header>

      <main class="admin-main">
        <router-view v-slot="{ Component }">
          <transition name="fade" mode="out-in">
            <component :is="Component" />
          </transition>
        </router-view>
      </main>
    </div>
  </div>
</template>

<style scoped>
.admin-layout {
  display: flex;
  min-height: 100vh;
  background: #f4f6fb;
}

.admin-sidebar {
  width: 220px;
  background: #0f172a;
  color: #cbd5f5;
  display: flex;
  flex-direction: column;
  transition: width 0.25s ease;
  position: sticky;
  top: 0;
  height: 100vh;
}

.admin-sidebar.collapsed {
  width: 72px;
}

.brand {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 20px 18px;
  border-bottom: 1px solid rgba(255,255,255,0.05);
}

.brand-icon {
  width: 34px;
  height: 34px;
  border-radius: 10px;
  background: linear-gradient(135deg, #6366f1, #8b5cf6);
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
}

.brand-text {
  font-size: 16px;
  font-weight: 600;
  color: #fff;
}

.admin-nav {
  flex: 1;
  padding: 12px 10px;
  display: flex;
  flex-direction: column;
  gap: 4px;
}

.nav-item {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 10px 14px;
  border-radius: 8px;
  cursor: pointer;
  color: #cbd5f5;
  font-size: 14px;
  transition: all 0.15s ease;
}

.nav-item:hover {
  background: rgba(255,255,255,0.06);
}

.nav-item.active {
  background: rgba(99,102,241,0.18);
  color: #fff;
}

.sidebar-footer {
  padding: 12px;
  border-top: 1px solid rgba(255,255,255,0.05);
}

.collapse-btn {
  display: flex;
  align-items: center;
  justify-content: center;
  height: 32px;
  border-radius: 8px;
  cursor: pointer;
  color: #94a3b8;
}

.collapse-btn:hover {
  background: rgba(255,255,255,0.06);
}

.admin-body {
  flex: 1;
  display: flex;
  flex-direction: column;
  min-width: 0;
}

.topbar {
  height: 56px;
  padding: 0 24px;
  display: flex;
  align-items: center;
  justify-content: space-between;
  background: #fff;
  border-bottom: 1px solid #e5e7eb;
  position: sticky;
  top: 0;
  z-index: 10;
}

.crumb {
  display: flex;
  align-items: center;
  gap: 10px;
  font-size: 15px;
  color: #0f172a;
  font-weight: 600;
}

.dot {
  width: 8px;
  height: 8px;
  border-radius: 50%;
  background: linear-gradient(135deg, #6366f1, #ec4899);
}

.topbar-actions {
  display: flex;
  align-items: center;
  gap: 12px;
}

.user-chip {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 4px 12px 4px 4px;
  background: #f8fafc;
  border-radius: 999px;
}

.user-chip .avatar {
  width: 30px;
  height: 30px;
  border-radius: 50%;
  background: linear-gradient(135deg, #3b82f6, #8b5cf6);
  color: #fff;
  display: flex;
  align-items: center;
  justify-content: center;
  font-weight: 600;
  font-size: 13px;
}

.user-chip .name {
  font-size: 13px;
  font-weight: 600;
  color: #0f172a;
  line-height: 1.2;
}

.user-chip .role {
  font-size: 11px;
  color: #64748b;
  line-height: 1.2;
}

.admin-main {
  flex: 1;
  padding: 24px;
  overflow-x: hidden;
}

.fade-enter-active, .fade-leave-active {
  transition: opacity 0.2s;
}
.fade-enter-from, .fade-leave-to {
  opacity: 0;
}

.admin-layout.mobile {
  flex-direction: column;
}

.admin-layout.mobile .admin-sidebar {
  width: 100%;
  height: auto;
  position: static;
  flex-direction: row;
  overflow-x: auto;
}

.admin-layout.mobile .admin-nav {
  flex-direction: row;
  padding: 8px;
}

.admin-layout.mobile .brand,
.admin-layout.mobile .sidebar-footer {
  display: none;
}

.admin-layout.mobile .nav-item {
  white-space: nowrap;
}
</style>
