import { useMemo } from 'react'
import type { Meta } from '../lib/types'
import { useGeometry, useMeasureData } from '../lib/hooks'
import { useStore } from '../store'
import MapDeck from './MapDeck'

function MapContainer({ meta, year, side }: { meta: Meta; year: number; side?: 'A' | 'B' }) {
  const mode = useStore((s) => s.mode)
  const measureId = useStore((s) => s.measureId)
  const features = useGeometry(mode)
  const data = useMeasureData(measureId)

  const measure = meta.measures.find((m) => m.id === measureId) ?? meta.measures[0]
  const values = useMemo(() => {
    if (!data) return {}
    return (mode === 'county' ? data.county : data.state)[String(year)] ?? {}
  }, [data, mode, year])

  const ready = features.length > 0 && data != null
  return (
    <div className="map-container">
      {!ready && <div className="map-loading">Loading {mode} geometry…</div>}
      {ready && (
        <MapDeck
          features={features}
          values={values}
          measure={measure}
          mode={mode}
          yearLabel={year}
          side={side}
        />
      )}
    </div>
  )
}

export default function MapStage({ meta }: { meta: Meta }) {
  const compare = useStore((s) => s.compare)
  const year = useStore((s) => s.year)
  const yearLeft = useStore((s) => s.yearLeft)
  const yearRight = useStore((s) => s.yearRight)

  if (!compare) {
    return (
      <div className="map-stage">
        <MapContainer meta={meta} year={year} />
      </div>
    )
  }
  return (
    <div className="map-stage split">
      <MapContainer meta={meta} year={yearLeft} side="A" />
      <div className="split-divider" />
      <MapContainer meta={meta} year={yearRight} side="B" />
    </div>
  )
}
