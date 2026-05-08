const KEY = import.meta.env.VITE_AMAP_KEY as string | undefined

export async function reverseGeocode(lat: number, lng: number): Promise<string | null> {
  if (!KEY) return null
  const url = `https://restapi.amap.com/v3/geocode/regeo?location=${lng.toFixed(6)},${lat.toFixed(6)}&key=${KEY}&radius=200&extensions=base&output=JSON`
  try {
    const res = await fetch(url)
    const json = await res.json()
    if (json.status !== '1') return null
    return json.regeocode?.formatted_address || null
  } catch {
    return null
  }
}

export function hasAmapKey(): boolean {
  return !!KEY
}
