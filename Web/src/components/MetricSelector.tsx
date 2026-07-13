import type { Meta } from '../lib/types'
import { useStore } from '../store'

export default function MetricSelector({ meta }: { meta: Meta }) {
  const measureId = useStore((s) => s.measureId)
  const setMeasure = useStore((s) => s.setMeasure)
  return (
    <div className="segmented metrics" role="tablist" aria-label="Health metric">
      {meta.measures.map((m) => (
        <button
          key={m.id}
          role="tab"
          aria-selected={m.id === measureId}
          className={m.id === measureId ? 'seg active' : 'seg'}
          onClick={() => setMeasure(m.id)}
          title={m.description}
        >
          {m.short}
        </button>
      ))}
    </div>
  )
}
