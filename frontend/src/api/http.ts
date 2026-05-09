import axios from 'axios'
import { apiBaseUrl, isNative } from '../utils/platform'
import { getToken } from '../utils/storage'
import router from '../router'

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
      if (router.currentRoute.value.name !== 'login') {
        router.replace('/login')
      }
    }
    return Promise.reject(err.response?.data || err)
  }
)

export default http
