import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import { authApi, usersApi, type AuthResponse } from '../api'

const ADMIN_MODE_KEY = 'adminMode'

export const useAuthStore = defineStore('auth', () => {
  const user = ref<AuthResponse['user'] | null>(null)
  const ready = ref(false)
  const adminMode = ref<boolean>(
    typeof window !== 'undefined' && localStorage.getItem(ADMIN_MODE_KEY) === 'true'
  )

  let initPromise: Promise<void> | null = null

  const isLoggedIn = () => !!user.value

  const isGuest = computed(() => user.value?.approvalStatus !== 'approved')

  const canAdmin = computed(
    () => !!user.value && (user.value.isSuperAdmin || user.value.roleLevel >= 5)
  )

  function setAdminMode(v: boolean) {
    adminMode.value = v
    if (typeof window !== 'undefined') {
      localStorage.setItem(ADMIN_MODE_KEY, String(v))
    }
  }

  async function init() {
    if (ready.value) return
    if (initPromise) return initPromise
    initPromise = (async () => {
      try {
        user.value = await usersApi.getMe()
        if (user.value?.isSuperAdmin && localStorage.getItem(ADMIN_MODE_KEY) === null) {
          setAdminMode(true)
        }
      } catch {
        user.value = null
      } finally {
        ready.value = true
      }
    })()
    return initPromise
  }

  async function login(username: string, password: string, rememberMe = true) {
    const res = await authApi.login({ username, password, rememberMe })
    user.value = res.user
    if (res.user.isSuperAdmin) {
      setAdminMode(true)
    } else if (!(res.user.roleLevel >= 5)) {
      setAdminMode(false)
    }
  }

  async function register(username: string, password: string, realName: string, email: string, groupIds: string[]) {
    const res = await authApi.register({ username, password, realName, email, groupIds })
    user.value = res.user
  }

  async function logout() {
    try { await authApi.logout() } catch {}
    user.value = null
    setAdminMode(false)
  }

  return {
    user, ready, adminMode,
    isGuest, canAdmin,
    isLoggedIn, setAdminMode,
    init, login, register, logout,
  }
})
