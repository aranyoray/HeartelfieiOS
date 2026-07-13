import { feature } from 'topojson-client'
import type { GeoMode, GeoFeature, MeasureData, Meta, Places } from './types'
import { INCLUDED_STATE_FIPS, STATE_ABBR } from './constants'

const BASE = import.meta.env.BASE_URL || '/'

async function getJson<T>(path: string): Promise<T> {
  const res = await fetch(`${BASE}${path}`.replace(/\/{2,}/g, '/'))
  if (!res.ok) throw new Error(`Failed to load ${path}: ${res.status}`)
  return (await res.json()) as T
}

// Cache successful loads but DROP failed promises so a transient network
// blip doesn't permanently stick the UI on an error.
function memoize<T>(loader: () => Promise<T>): () => Promise<T> {
  let cached: Promise<T> | null = null
  return () => {
    if (cached) return cached
    const p = loader().catch((e) => {
      cached = null
      throw e
    })
    cached = p
    return p
  }
}

export const loadMeta = memoize(() => getJson<Meta>('data/meta.json'))
export const loadPlaces = memoize(() => getJson<Places>('data/places.json'))

const geoCache = new Map<GeoMode, Promise<GeoFeature[]>>()
export function loadGeometry(mode: GeoMode): Promise<GeoFeature[]> {
  const cached = geoCache.get(mode)
  if (cached) return cached
  const file = mode === 'county' ? 'counties-10m' : 'states-10m'
  const idLen = mode === 'county' ? 5 : 2
  const promise = getJson<any>(`geo/${file}.json`)
    .then((topo) => {
      const obj = mode === 'county' ? topo.objects.counties : topo.objects.states
      const fc = feature(topo, obj) as unknown as { features: any[] }
      const out: GeoFeature[] = []
      for (const f of fc.features) {
        const id = String(f.id).padStart(idLen, '0')
        const stfips = id.slice(0, 2)
        if (!INCLUDED_STATE_FIPS.has(stfips)) continue
        out.push({
          type: 'Feature',
          id,
          properties: { name: f.properties?.name ?? id, st: STATE_ABBR[stfips] ?? '' },
          geometry: f.geometry,
        })
      }
      return out
    })
    .catch((e) => {
      geoCache.delete(mode)
      throw e
    })
  geoCache.set(mode, promise)
  return promise
}

const measureCache = new Map<string, Promise<MeasureData>>()
export function loadMeasure(measureId: string): Promise<MeasureData> {
  const cached = measureCache.get(measureId)
  if (cached) return cached
  const promise = Promise.all([
    getJson<MeasureData['county']>(`data/county/${measureId}.json`),
    getJson<MeasureData['state']>(`data/state/${measureId}.json`),
  ])
    .then(([county, state]) => ({ county, state }))
    .catch((e) => {
      measureCache.delete(measureId)
      throw e
    })
  measureCache.set(measureId, promise)
  return promise
}
