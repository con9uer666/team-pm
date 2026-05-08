import { Geolocation } from '@capacitor/geolocation'
import { isNative } from './platform'

export interface GeoPosition {
  lat: number
  lng: number
  accuracy: number
}

const ERRORS: Record<number, string> = {
  1: '位置权限被拒绝，请在设置中允许本应用定位',
  2: '位置信息不可用，请检查 GPS 或网络',
  3: '定位超时，请重试',
}

async function getNativePosition(): Promise<GeoPosition> {
  try {
    const perm = await Geolocation.checkPermissions()
    if (perm.location !== 'granted') {
      const req = await Geolocation.requestPermissions({ permissions: ['location'] })
      if (req.location !== 'granted') {
        throw new Error(ERRORS[1])
      }
    }
    const p = await Geolocation.getCurrentPosition({
      enableHighAccuracy: true,
      timeout: 10000,
      maximumAge: 60000,
    })
    return {
      lat: p.coords.latitude,
      lng: p.coords.longitude,
      accuracy: p.coords.accuracy,
    }
  } catch (e: any) {
    const msg = typeof e?.message === 'string' ? e.message : '定位失败'
    throw new Error(msg)
  }
}

function getWebPosition(opts: PositionOptions): Promise<GeoPosition> {
  return new Promise((resolve, reject) => {
    if (!('geolocation' in navigator)) {
      return reject(new Error('浏览器不支持定位'))
    }
    navigator.geolocation.getCurrentPosition(
      (p) =>
        resolve({
          lat: p.coords.latitude,
          lng: p.coords.longitude,
          accuracy: p.coords.accuracy,
        }),
      (e) => reject(new Error(ERRORS[e.code] || '定位失败')),
      opts,
    )
  })
}

export function getPosition(
  opts: PositionOptions = { enableHighAccuracy: true, timeout: 10000, maximumAge: 60000 },
): Promise<GeoPosition> {
  return isNative ? getNativePosition() : getWebPosition(opts)
}

export function haversine(lat1: number, lng1: number, lat2: number, lng2: number): number {
  const R = 6371000
  const toRad = (v: number) => (v * Math.PI) / 180
  const dLat = toRad(lat2 - lat1)
  const dLng = toRad(lng2 - lng1)
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLng / 2) ** 2
  return 2 * R * Math.asin(Math.sqrt(a))
}
