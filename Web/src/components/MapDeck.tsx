import { useMemo, useRef, useState } from 'react'
import type { CSSProperties } from 'react'
import DeckGL from '@deck.gl/react'
import { GeoJsonLayer } from '@deck.gl/layers'
import type { AreaSelection, GeoFeature, GeoMode, Measure } from '../lib/types'
import { fillColor } from '../lib/colors'
import { formatValue } from '../lib/format'
import { COMPARE_RGB } from '../lib/constants'
import { useStore } from '../store'

const NO_DATA_LINE: [number, number, number, number] = [12, 16, 28, 140]

interface Props {
  features: GeoFeature[]
  values: Record<string, number>
  measure: Measure
  mode: GeoMode
  yearLabel: number
  side?: 'A' | 'B'
}

interface Hover {
  x: number
  y: number
  id: string
  name: string
  st: string
  value: number | undefined
}

export default function MapDeck({ features, values, measure, mode, yearLabel, side }: Props) {
  const viewState = useStore((s) => s.viewState)
  const setViewState = useStore((s) => s.setViewState)
  const selections = useStore((s) => s.selections)
  const highlightId = useStore((s) => s.highlightId)
  const toggleSelection = useStore((s) => s.toggleSelection)
  const [hover, setHover] = useState<Hover | null>(null)
  const containerRef = useRef<HTMLDivElement>(null)

  const selIndex = useMemo(() => {
    const m = new Map<string, number>()
    selections.forEach((s, i) => m.set(s.id, i))
    return m
  }, [selections])
  const selKey = selections.map((s) => s.id).join(',')

  // Flat choropleth (no extrusion); the camera pitch still gives a tilted,
  // perspective "3D" view of the map plane.
  const layer = useMemo(
    () =>
      new GeoJsonLayer({
        id: `geo-${mode}-${side ?? 'main'}`,
        data: features as any,
        pickable: true,
        stroked: true,
        filled: true,
        extruded: false,
        getFillColor: (f: any) => fillColor(values[f.id], measure.colorDomain, 235),
        getLineColor: (f: any) => {
          const idx = selIndex.get(f.id)
          if (idx != null) return [...COMPARE_RGB[idx], 255] as [number, number, number, number]
          if (highlightId === f.id) return [255, 255, 255, 255] as [number, number, number, number]
          return NO_DATA_LINE
        },
        getLineWidth: (f: any) =>
          selIndex.has(f.id) || highlightId === f.id ? 3 : mode === 'state' ? 1 : 0.4,
        lineWidthUnits: 'pixels',
        lineWidthMinPixels: 0.3,
        autoHighlight: true,
        highlightColor: [255, 255, 255, 60],
        onHover: (info) => {
          const f = info.object as GeoFeature | undefined
          if (!f) return setHover(null)
          setHover({
            x: info.x,
            y: info.y,
            id: f.id,
            name: f.properties.name,
            st: f.properties.st,
            value: values[f.id],
          })
        },
        onClick: (info) => {
          const f = info.object as GeoFeature | undefined
          if (!f) return
          const label = mode === 'county' ? `${f.properties.name}, ${f.properties.st}` : f.properties.name
          toggleSelection({ kind: mode, id: f.id, label } as AreaSelection)
        },
        updateTriggers: {
          getFillColor: [measure.id, yearLabel],
          getLineColor: [selKey, highlightId],
          getLineWidth: [selKey, highlightId, mode],
        },
      }),
    [features, values, measure, mode, side, selIndex, selKey, highlightId, yearLabel, toggleSelection],
  )

  // Anchor the tooltip at the cursor, flipping to the other side near the
  // right/bottom edges so it stays on-screen and snug to the pointer.
  let tipStyle: CSSProperties | undefined
  if (hover) {
    const el = containerRef.current
    const w = el?.clientWidth ?? 0
    const h = el?.clientHeight ?? 0
    const flipX = w > 0 && hover.x > w - 250
    const flipY = h > 0 && hover.y > h - 150
    tipStyle = {
      left: hover.x,
      top: hover.y,
      transform: `translate(${flipX ? 'calc(-100% - 16px)' : '16px'}, ${flipY ? 'calc(-100% - 16px)' : '16px'})`,
    }
  }

  return (
    <div className="map-deck" ref={containerRef}>
      <DeckGL
        style={{ position: 'absolute', top: '0', left: '0', width: '100%', height: '100%' }}
        viewState={viewState}
        onViewStateChange={(e: any) => setViewState(e.viewState)}
        controller={{
          dragRotate: true,
          touchRotate: true,
          inertia: true,
          minZoom: 2.5,
          maxZoom: 12,
          maxPitch: 60,
        } as any}
        layers={[layer]}
        getCursor={({ isHovering }) => (isHovering ? 'pointer' : 'grab')}
      />
      {side && <div className="map-side-badge">{yearLabel}</div>}
      {hover && (
        <div className="map-tooltip" style={tipStyle}>
          <div className="tt-title">
            {hover.name}
            {hover.st ? <span className="tt-st">{hover.st}</span> : null}
          </div>
          <div className="tt-row">
            <span className="tt-metric">{measure.short}</span>
            <span className="tt-value">{formatValue(hover.value, measure.unit)}</span>
          </div>
          <div className="tt-foot">
            {yearLabel} · {measure.unit} ·{' '}
            {selIndex.has(hover.id) ? 'in comparison' : 'click to compare'}
          </div>
        </div>
      )}
    </div>
  )
}
