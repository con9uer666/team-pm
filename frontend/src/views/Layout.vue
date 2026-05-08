<script setup lang="ts">
import { ref, computed, onMounted, onUnmounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useAuthStore } from '../stores/auth'

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

interface NavItem {
  icon: string
  label: string
  path: string
  name: string
  guestAllowed?: boolean
}

const navItems = computed<NavItem[]>(() => {
  const full: NavItem[] = [
    { icon: 'chart-trending-o', label: '仪表盘', path: '/', name: 'home' },
    { icon: 'todo-list-o', label: '任务中心', path: '/tasks', name: 'tasks' },
    { icon: 'friends-o', label: '协作空间', path: '/collaborate', name: 'collaborate' },
    { icon: 'apartment-o', label: '我的空间', path: '/space', name: 'space' },
    { icon: 'clock-o', label: '打卡考勤', path: '/attendance', name: 'attendance' },
    { icon: 'cluster-o', label: '团队架构', path: '/team-structure', name: 'team-structure', guestAllowed: true },
    { icon: 'bell', label: '消息通知', path: '/notifications', name: 'notifications', guestAllowed: true },
    { icon: 'user-o', label: '个人中心', path: '/profile', name: 'profile', guestAllowed: true },
  ]
  if (auth.isGuest) return full.filter(n => n.guestAllowed)
  return full
})

function isActive(name: string) {
  return route.name === name
}

function navigateTo(path: string) {
  router.push(path)
}

function switchToAdmin() {
  auth.setAdminMode(true)
  router.push('/admin')
}
</script>

<template>
  <div class="layout" :class="{ 'layout--mobile': isMobile }">
    <!-- Desktop Sidebar -->
    <aside v-if="!isMobile" class="sidebar" :class="{ 'sidebar--collapsed': sidebarCollapsed }">
      <div class="sidebar__header">
        <div class="sidebar__logo">
          <div class="logo-icon">
            <van-icon name="flag-o" size="22" color="#fff" />
          </div>
          <transition name="fade">
            <span v-if="!sidebarCollapsed" class="logo-text">战队管理</span>
          </transition>
        </div>
        <div class="sidebar__toggle" @click="sidebarCollapsed = !sidebarCollapsed">
          <van-icon :name="sidebarCollapsed ? 'arrow' : 'arrow-left'" size="16" color="#94a3b8" />
        </div>
      </div>

      <nav class="sidebar__nav">
        <div
          v-for="(item, index) in navItems"
          :key="item.name"
          class="nav-item"
          :class="{ 'nav-item--active': isActive(item.name) }"
          :style="{ animationDelay: `${index * 0.05}s` }"
          @click="navigateTo(item.path)"
        >
          <div class="nav-item__icon">
            <van-icon :name="item.icon" size="20" />
          </div>
          <transition name="fade">
            <span v-if="!sidebarCollapsed" class="nav-item__label">{{ item.label }}</span>
          </transition>
          <div v-if="isActive(item.name)" class="nav-item__indicator"></div>
        </div>

        <div
          v-if="auth.canAdmin && !auth.isGuest"
          class="nav-item nav-item--admin"
          @click="switchToAdmin"
        >
          <div class="nav-item__icon">
            <van-icon name="setting-o" size="20" />
          </div>
          <transition name="fade">
            <span v-if="!sidebarCollapsed" class="nav-item__label">进入后台</span>
          </transition>
        </div>
      </nav>

      <div class="sidebar__footer">
        <div class="user-card" @click="navigateTo('/profile')">
          <div class="user-avatar">
            {{ (auth.user?.realName || 'U').charAt(0) }}
          </div>
          <transition name="fade">
            <div v-if="!sidebarCollapsed" class="user-info">
              <div class="user-name">{{ auth.user?.realName || '用户' }}</div>
              <div class="user-role">{{ auth.user?.username }}</div>
            </div>
          </transition>
        </div>
      </div>
    </aside>

    <!-- Main Content -->
    <main class="main" :class="{ 'main--with-sidebar': !isMobile, 'main--collapsed': !isMobile && sidebarCollapsed }">
      <div v-if="auth.isGuest" class="guest-banner">
        <van-icon name="clock-o" /> 账号审核中，你暂时只能查看团队架构和通知。
        <van-button size="mini" plain @click="router.push('/pending')">查看审核状态</van-button>
      </div>
      <router-view v-slot="{ Component }">
        <transition name="page" mode="out-in">
          <component :is="Component" />
        </transition>
      </router-view>
    </main>

    <!-- Mobile Bottom Tab -->
    <van-tabbar v-if="isMobile" route class="mobile-tabbar">
      <template v-if="!auth.isGuest">
        <van-tabbar-item icon="home-o" to="/">首页</van-tabbar-item>
        <van-tabbar-item icon="todo-list-o" to="/tasks">任务</van-tabbar-item>
        <van-tabbar-item icon="apartment-o" to="/space">空间</van-tabbar-item>
        <van-tabbar-item icon="bell" to="/notifications">通知</van-tabbar-item>
        <van-tabbar-item icon="user-o" to="/profile">我的</van-tabbar-item>
      </template>
      <template v-else>
        <van-tabbar-item icon="cluster-o" to="/team-structure">架构</van-tabbar-item>
        <van-tabbar-item icon="bell" to="/notifications">通知</van-tabbar-item>
        <van-tabbar-item icon="user-o" to="/profile">我的</van-tabbar-item>
      </template>
    </van-tabbar>
  </div>
</template>

<style scoped>
.layout {
  min-height: 100vh;
  display: flex;
}

.layout--mobile {
  flex-direction: column;
  padding-bottom: 50px;
}

/* Sidebar */
.sidebar {
  width: var(--sidebar-width);
  background: var(--sidebar-bg);
  display: flex;
  flex-direction: column;
  position: fixed;
  top: 0;
  left: 0;
  height: 100vh;
  z-index: 100;
  transition: width var(--transition-normal);
  overflow: hidden;
}

.sidebar--collapsed {
  width: 72px;
}

.sidebar__header {
  padding: 20px 16px;
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.sidebar__logo {
  display: flex;
  align-items: center;
  gap: 12px;
}

.logo-icon {
  width: 38px;
  height: 38px;
  background: var(--gradient-blue);
  border-radius: 10px;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
  animation: float 3s ease-in-out infinite;
}

.logo-text {
  font-size: 18px;
  font-weight: 700;
  color: #fff;
  white-space: nowrap;
}

.sidebar__toggle {
  width: 28px;
  height: 28px;
  display: flex;
  align-items: center;
  justify-content: center;
  border-radius: 6px;
  cursor: pointer;
  transition: background var(--transition-fast);
}

.sidebar__toggle:hover {
  background: rgba(255, 255, 255, 0.1);
}

.sidebar__nav {
  flex: 1;
  padding: 8px 12px;
  display: flex;
  flex-direction: column;
  gap: 4px;
}

.nav-item {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 12px 14px;
  border-radius: 10px;
  cursor: pointer;
  position: relative;
  transition: all var(--transition-fast);
  animation: fadeInLeft 0.3s ease both;
}

.nav-item:hover {
  background: rgba(255, 255, 255, 0.06);
}

.nav-item--active {
  background: rgba(59, 130, 246, 0.15);
}

.nav-item--admin {
  margin-top: 12px;
  border: 1px dashed rgba(139, 92, 246, 0.5);
}

.nav-item__icon {
  width: 36px;
  height: 36px;
  display: flex;
  align-items: center;
  justify-content: center;
  border-radius: 8px;
  color: var(--sidebar-text);
  transition: all var(--transition-fast);
  flex-shrink: 0;
}

.nav-item--active .nav-item__icon {
  color: var(--sidebar-active);
  background: rgba(59, 130, 246, 0.1);
}

.nav-item__label {
  font-size: 14px;
  color: var(--sidebar-text);
  white-space: nowrap;
  transition: color var(--transition-fast);
}

.nav-item--active .nav-item__label {
  color: var(--sidebar-text-active);
  font-weight: 500;
}

.nav-item__indicator {
  position: absolute;
  left: 0;
  top: 50%;
  transform: translateY(-50%);
  width: 3px;
  height: 20px;
  background: var(--sidebar-active);
  border-radius: 0 3px 3px 0;
  animation: scaleIn 0.3s ease;
}

.sidebar__footer {
  padding: 16px;
  border-top: 1px solid rgba(255, 255, 255, 0.06);
}

.user-card {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 10px;
  border-radius: 10px;
  cursor: pointer;
  transition: background var(--transition-fast);
}

.user-card:hover {
  background: rgba(255, 255, 255, 0.06);
}

.user-avatar {
  width: 36px;
  height: 36px;
  background: var(--gradient-cyan);
  border-radius: 10px;
  display: flex;
  align-items: center;
  justify-content: center;
  color: #fff;
  font-weight: 600;
  font-size: 14px;
  flex-shrink: 0;
}

.user-name {
  font-size: 13px;
  color: #fff;
  font-weight: 500;
}

.user-role {
  font-size: 11px;
  color: var(--sidebar-text);
}

.main {
  flex: 1;
  padding: 24px;
  min-height: 100vh;
}

.main--with-sidebar {
  margin-left: var(--sidebar-width);
  transition: margin-left var(--transition-normal);
}

.main--collapsed {
  margin-left: 72px;
}

.guest-banner {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 10px 14px;
  margin-bottom: 16px;
  background: rgba(251, 191, 36, 0.12);
  border: 1px solid rgba(251, 191, 36, 0.35);
  border-radius: 10px;
  color: #d97706;
  font-size: 13px;
}

.page-enter-active {
  animation: fadeInUp 0.35s ease both;
}

.page-leave-active {
  animation: fadeInUp 0.15s ease reverse both;
}

.fade-enter-active, .fade-leave-active {
  transition: opacity 0.2s ease;
}
.fade-enter-from, .fade-leave-to {
  opacity: 0;
}

.mobile-tabbar {
  box-shadow: 0 -2px 12px rgba(0, 0, 0, 0.06) !important;
}
</style>
