import { useEffect, useState } from 'react'
import type { GeoFeature, GeoMode, MeasureData, Meta, Places } from './types'
import { loadGeometry, loadMeasure, loadMeta, loadPlaces } from './data'

function logError(label: string, err: unknown) {
  if (typeof console !== 'undefined') console.error(`[DailyDil] ${label}:`, err)
}

export function useMeta(): Meta | null {
  const [meta, setMeta] = useState<Meta | null>(null)
  useEffect(() => {
    let live = true
    loadMeta()
      .then((m) => live && setMeta(m))
      .catch((e) => logError('loadMeta failed', e))
    return () => {
      live = false
    }
  }, [])
  return meta
}

export function usePlaces(): Places | null {
  const [places, setPlaces] = useState<Places | null>(null)
  useEffect(() => {
    let live = true
    loadPlaces()
      .then((p) => live && setPlaces(p))
      .catch((e) => logError('loadPlaces failed', e))
    return () => {
      live = false
    }
  }, [])
  return places
}

export function useGeometry(mode: GeoMode): GeoFeature[] {
  const [features, setFeatures] = useState<GeoFeature[]>([])
  useEffect(() => {
    let live = true
    loadGeometry(mode)
      .then((f) => live && setFeatures(f))
      .catch((e) => logError(`loadGeometry(${mode}) failed`, e))
    return () => {
      live = false
    }
  }, [mode])
  return features
}

export function useMeasureData(measureId: string): MeasureData | null {
  const [data, setData] = useState<MeasureData | null>(null)
  useEffect(() => {
    let live = true
    setData(null)
    loadMeasure(measureId)
      .then((d) => live && setData(d))
      .catch((e) => logError(`loadMeasure(${measureId}) failed`, e))
    return () => {
      live = false
    }
  }, [measureId])
  return data
}
