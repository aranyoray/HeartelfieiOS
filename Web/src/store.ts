import { create } from 'zustand'
import { FlyToInterpolator } from '@deck.gl/core'
import type { AreaSelection, GeoMode } from './lib/types'
import { INITIAL_VIEW, MAX_COMPARE } from './lib/constants'

type ViewState = Record<string, any>

interface AppState {
  measureId: string
  mode: GeoMode
  year: number
  compare: boolean
  yearLeft: number
  yearRight: number
  playing: boolean
  viewState: ViewState
  selections: AreaSelection[]
  highlightId: string | null
  years: number[]

  initYears: (years: number[], measureId: string) => void
  setMeasure: (id: string) => void
  setMode: (mode: GeoMode) => void
  setYear: (y: number) => void
  setCompare: (b: boolean) => void
  setYearLeft: (y: number) => void
  setYearRight: (y: number) => void
  setPlaying: (b: boolean) => void
  setViewState: (vs: ViewState) => void
  flyTo: (lon: number, lat: number, zoom?: number) => void
  toggleSelection: (sel: AreaSelection) => void
  removeSelection: (id: string) => void
  clearSelections: () => void
  setHighlight: (id: string | null) => void
}

export const useStore = create<AppState>((set) => ({
  measureId: 'BPHIGH',
  mode: 'county',
  year: 2022,
  compare: false,
  yearLeft: 2016,
  yearRight: 2022,
  playing: false,
  viewState: { ...INITIAL_VIEW },
  selections: [],
  highlightId: null,
  years: [],

  initYears: (years, measureId) =>
    set({
      years,
      measureId,
      year: years[years.length - 1],
      yearLeft: years[0],
      yearRight: years[years.length - 1],
    }),

  setMeasure: (id) => set({ measureId: id }),
  setMode: (mode) =>
    set({ mode, selections: [], highlightId: null, playing: false }),
  setYear: (y) => set({ year: y }),
  setCompare: (b) => set({ compare: b, playing: false }),
  setYearLeft: (y) => set({ yearLeft: y }),
  setYearRight: (y) => set({ yearRight: y }),
  setPlaying: (b) => set({ playing: b }),

  setViewState: (vs) => set({ viewState: vs }),
  flyTo: (lon, lat, zoom) =>
    set((s) => ({
      highlightId: s.highlightId,
      viewState: {
        ...s.viewState,
        longitude: lon,
        latitude: lat,
        zoom: zoom ?? Math.max(6, s.viewState.zoom ?? 6),
        transitionDuration: 1200,
        transitionInterpolator: new FlyToInterpolator({ speed: 1.6 }),
      },
    })),

  toggleSelection: (sel) =>
    set((s) => {
      const exists = s.selections.find((x) => x.id === sel.id)
      if (exists) return { selections: s.selections.filter((x) => x.id !== sel.id) }
      if (s.selections.length >= MAX_COMPARE) return {}
      return { selections: [...s.selections, sel] }
    }),
  removeSelection: (id) =>
    set((s) => ({ selections: s.selections.filter((x) => x.id !== id) })),
  clearSelections: () => set({ selections: [] }),
  setHighlight: (id) => set({ highlightId: id }),
}))

export { MAX_COMPARE }
