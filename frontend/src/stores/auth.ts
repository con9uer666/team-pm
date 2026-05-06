import { defineStore } from 'pinia'
import { ref } from 'vue'
import { authApi, type AuthResponse } from '../api'

export const useAuthStore = defineStore('auth', () => {
  const token = ref(localStorage.getItem('token') || '')
  const user = ref<AuthResponse['user'] | null>(null)

  const isLoggedIn = () => !!token.value

  async function login(username: string, password: string) {
    const res = await authApi.login({ username, password })
    console.log('login response:', res)
    token.value = res.accessToken
    user.value = res.user
    localStorage.setItem('token', res.accessToken)
  }

  async function register(username: string, password: string, realName: string) {
    const res = await authApi.register({ username, password, realName })
    console.log('register response:', res)
    token.value = res.accessToken
    user.value = res.user
    localStorage.setItem('token', res.accessToken)
  }

  function logout() {
    token.value = ''
    user.value = null
    localStorage.removeItem('token')
  }

  return { token, user, isLoggedIn, login, register, logout }
})
