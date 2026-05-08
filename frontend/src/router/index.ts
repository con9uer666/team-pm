import { createRouter, createWebHistory } from 'vue-router'
import { useAuthStore } from '../stores/auth'

const router = createRouter({
  history: createWebHistory(),
  routes: [
    {
      path: '/login',
      name: 'login',
      component: () => import('../views/Login.vue'),
    },
    {
      path: '/pending',
      name: 'pending',
      component: () => import('../views/Pending.vue'),
      meta: { requiresAuth: true },
    },
    {
      path: '/admin',
      component: () => import('../views/admin/AdminLayout.vue'),
      meta: { requiresAuth: true, requiresAdmin: true },
      children: [
        { path: '', name: 'admin-dashboard', component: () => import('../views/admin/AdminDashboard.vue') },
        { path: 'users', name: 'admin-users', component: () => import('../views/admin/AdminUsers.vue') },
        { path: 'org', name: 'admin-org', component: () => import('../views/admin/AdminOrg.vue') },
        { path: 'tasks', name: 'admin-tasks', component: () => import('../views/admin/AdminTasks.vue') },
        { path: 'meetings', name: 'admin-meetings', component: () => import('../views/admin/AdminMeetings.vue') },
        { path: 'objectives', name: 'admin-objectives', component: () => import('../views/admin/AdminObjectives.vue') },
        { path: 'fences', name: 'admin-fences', component: () => import('../views/admin/AdminFences.vue') },
      ],
    },
    {
      path: '/',
      component: () => import('../views/Layout.vue'),
      meta: { requiresAuth: true },
      children: [
        { path: '', name: 'home', component: () => import('../views/Home.vue') },
        { path: 'tasks', name: 'tasks', component: () => import('../views/Tasks.vue') },
        { path: 'collaborate', name: 'collaborate', component: () => import('../views/Collaborate.vue') },
        { path: 'notifications', name: 'notifications', component: () => import('../views/Notifications.vue') },
        { path: 'profile', name: 'profile', component: () => import('../views/Profile.vue') },
        { path: 'meetings', name: 'meetings', component: () => import('../views/Meetings.vue') },
        { path: 'team-structure', name: 'team-structure', component: () => import('../views/TeamStructure.vue') },
        { path: 'space', name: 'space', component: () => import('../views/MySpace.vue') },
        { path: 'space/:scope/:id', name: 'space-detail', component: () => import('../views/SpaceDetail.vue') },
        { path: 'attendance', name: 'attendance', component: () => import('../views/Attendance.vue') },
      ],
    },
  ],
})

const GUEST_ALLOWED = new Set<string>([
  'pending',
  'profile',
  'notifications',
  'team-structure',
])

router.beforeEach(async (to) => {
  const auth = useAuthStore()
  if (!auth.ready) {
    await auth.init()
  }
  const requiresAuth = to.matched.some(record => record.meta.requiresAuth)
  const requiresAdmin = to.matched.some(record => record.meta.requiresAdmin)

  if (!requiresAuth) {
    if (to.name === 'login' && auth.user) {
      return auth.canAdmin && auth.adminMode ? '/admin' : '/'
    }
    return
  }

  if (!auth.user) {
    return '/login'
  }

  if (auth.isGuest) {
    if (to.name && GUEST_ALLOWED.has(to.name as string)) return
    return '/pending'
  }

  if (requiresAdmin && !auth.canAdmin) {
    return '/'
  }

  if (!requiresAdmin && auth.canAdmin && auth.adminMode) {
    return '/admin'
  }
})

export default router
