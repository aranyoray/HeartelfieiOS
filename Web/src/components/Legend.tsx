import type { Meta } from '../lib/types'
import { legendGradient } from '../lib/colors'
import { useStore } from '../store'

export default function Legend({ meta }: { meta: Meta }) {
  const measureId = useStore((s) => s.measureId)
  const measure = meta.measures.find((m) => m.id === measureId) ?? meta.measures[0]
  const [lo, hi] = measure.colorDomain

  return (
    <div className="legend glass">
      <div className="legend-title">
        {measure.label}
        <span className="legend-unit">{measure.unit}</span>
      </div>
      <div className="legend-bar" style={{ background: legendGradient() }} />
      <div className="legend-scale">
        <span>{lo}</span>
        <span className="legend-mid">higher community indicator →</span>
        <span>{hi}</span>
      </div>
      <div className="legend-hint">
        Redder = a higher {measure.label.toLowerCase()} indicator for the area. Drag to pan,
        right-drag (or two-finger drag) to tilt &amp; rotate.
      </div>
    </div>
  )
}
