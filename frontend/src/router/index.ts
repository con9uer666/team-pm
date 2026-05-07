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
      path: '/',
      component: () => import('../views/Layout.vue'),
      meta: { requiresAuth: true },
      children: [
        { path: '', name: 'home', component: () => import('../views/Home.vue') },
        { path: 'tasks', name: 'tasks', component: () => import('../views/Tasks.vue') },
        { path: 'collaborate', name: 'collaborate', component: () => import('../views/Collaborate.vue') },
        { path: 'notifications', name: 'notifications', component: () => import('../views/Notifications.vue') },
        { path: 'profile', name: 'profile', component: () => import('../views/Profile.vue') },
        { path: 'admin/members', name: 'admin-members', component: () => import('../views/AdminMembers.vue') },
        { path: 'meetings', name: 'meetings', component: () => import('../views/Meetings.vue') },
        { path: 'team-structure', name: 'team-structure', component: () => import('../views/TeamStructure.vue') },
      ],
    },
  ],
})

router.beforeEach((to) => {
  const auth = useAuthStore()
  const requiresAuth = to.matched.some(record => record.meta.requiresAuth)
  if (requiresAuth && !auth.user) {
    return '/login'
  }
})

export default router
