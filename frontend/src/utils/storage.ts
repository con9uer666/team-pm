import { Preferences } from '@capacitor/preferences'
import { isNative } from './platform'

const KEY = 'auth_token'

export async function getToken(): Promise<string | null> {
  if (!isNative) return null
  const { value } = await Preferences.get({ key: KEY })
  return value
}

export async function setToken(token: string): Promise<void> {
  if (!isNative) return
  await Preferences.set({ key: KEY, value: token })
}

export async function removeToken(): Promise<void> {
  if (!isNative) return
  await Preferences.remove({ key: KEY })
}
