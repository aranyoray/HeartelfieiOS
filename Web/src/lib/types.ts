export interface Measure {
  id: string
  label: string
  short: string
  unit: string
  description: string
  colorDomain: [number, number]
  elevationDomain: [number, number]
  dataMin: number
  dataMax: number
}

export interface Meta {
  title: string
  source: string
  sourceUrl: string
  isPlaceholder: boolean
  adjustment: string
  generated: string
  years: number[]
  measures: Measure[]
  countyCount: number
  notes: string[]
}

/** { [year]: { [fips]: value } } */
export type ValuesByYear = Record<string, Record<string, number>>

export interface MeasureData {
  county: ValuesByYear
  state: ValuesByYear
}

export type GeoMode = 'county' | 'state'

export interface PlaceItem {
  id: string
  name: string
  st: string
  label: string
  lon: number
  lat: number
}

/** [zip, lon, lat] */
export type ZipTuple = [string, number, number]

export interface Places {
  counties: PlaceItem[]
  states: PlaceItem[]
  zips: ZipTuple[]
}

export interface AreaSelection {
  kind: GeoMode
  id: string
  label: string
}

export interface HoverInfo {
  x: number
  y: number
  id: string
  name: string
  value: number | undefined
}

/** A GeoJSON-ish polygon feature as decoded from TopoJSON. */
export interface GeoFeature {
  type: 'Feature'
  id: string
  properties: { name: string; st: string }
  geometry: unknown
}
