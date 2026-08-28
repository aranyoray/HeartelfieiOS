import { useEffect, useRef } from 'react'
import { Link } from 'react-router-dom'
import { useMeta } from './lib/hooks'
import { useStore } from './store'
import TopBar from './components/TopBar'
import MapStage from './components/MapStage'
import TimeSlider from './components/TimeSlider'
import Legend from './components/Legend'
import ComparisonPanel from './components/ComparisonPanel'

export default function App() {
  const meta = useMeta()
  const initYears = useStore((s) => s.initYears)
  const inited = useRef(false)

  useEffect(() => {
    if (meta && !inited.current) {
      inited.current = true
      const measureId = useStore.getState().measureId
      const valid = meta.measures.find((m) => m.id === measureId)?.id ?? meta.measures[0].id
      initYears(meta.years, valid)
    }
  }, [meta, initYears])

  if (!meta) {
    return (
      <div className="boot">
        <div className="boot-pulse" />
        <span>Loading DailyDil…</span>
      </div>
    )
  }

  return (
    <div className="app">
      <MapStage meta={meta} />
      <TopBar meta={meta} />
      <div className="time-wrap">
        <TimeSlider years={meta.years} />
      </div>
      <Legend meta={meta} />
      <ComparisonPanel meta={meta} />
      <footer className="mini-foot">
        <Link to="/privacy">Privacy</Link>
        <span>·</span>
        <Link to="/support">Support</Link>
        <span>·</span>
        <Link to="/terms">Terms</Link>
        <span>·</span>
        <a href={meta.sourceUrl} target="_blank" rel="noreferrer">
          CDC PLACES
        </a>
        <span>·</span>
        <span className="mini-foot-note" title="Information only — not medical advice.">
          Not medical advice
        </span>
      </footer>
    </div>
  )
}
