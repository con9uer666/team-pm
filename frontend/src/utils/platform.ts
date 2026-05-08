import { Capacitor } from '@capacitor/core'

export const isNative = Capacitor.isNativePlatform()
export const platform = Capacitor.getPlatform()
export const apiBaseUrl = (import.meta.env.VITE_API_BASE as string) || '/api'
