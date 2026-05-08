import axios from 'axios'
import { apiBaseUrl, isNative } from '../utils/platform'
import { getToken } from '../utils/storage'

const http = axios.create({
  baseURL: apiBaseUrl,
  timeout: 10000,
  withCredentials: !isNative,
})

http.interceptors.request.use(async (config) => {
  if (isNative) {
    const token = await getToken()
    if (token) {
      config.headers.set('Authorization', `Bearer ${token}`)
    }
  }
  return config
})

http.interceptors.response.use(
  (res) => res.data,
  (err) => {
    if (err.response?.status === 401) {
      const isLoginPage = window.location.pathname === '/login'
      if (!isLoginPage) {
        window.location.href = '/login'
      }
    }
    return Promise.reject(err.response?.data || err)
  }
)

export default http
