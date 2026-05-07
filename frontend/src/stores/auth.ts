import { defineStore } from 'pinia'
import { ref } from 'vue'
import { authApi, usersApi, type AuthResponse } from '../api'

export const useAuthStore = defineStore('auth', () => {
  const user = ref<AuthResponse['user'] | null>(null)
  const ready = ref(false)

  const isLoggedIn = () => !!user.value

  async function init() {
    try {
      user.value = await usersApi.getMe()
    } catch {
      user.value = null
    } finally {
      ready.value = true
    }
  }

  async function login(username: string, password: string) {
    const res = await authApi.login({ username, password })
    user.value = res.user
  }

  async function register(username: string, password: string, realName: string, email: string) {
    const res = await authApi.register({ username, password, realName, email })
    user.value = res.user
  }

  async function logout() {
    try { await authApi.logout() } catch {}
    user.value = null
  }

  return { user, ready, isLoggedIn, init, login, register, logout }
})
