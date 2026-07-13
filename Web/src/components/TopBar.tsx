import type { Meta } from '../lib/types'
import MetricSelector from './MetricSelector'
import ModeToggle from './ModeToggle'
import SearchBar from './SearchBar'
import AboutModal from './AboutModal'

export default function TopBar({ meta }: { meta: Meta }) {
  return (
    <header className="topbar glass">
      <div className="brand">
        <span className="brand-pulse" aria-hidden />
        <div className="brand-text">
          <span className="brand-name">Heartelfie</span>
          <span className="brand-sub">U.S. Cardiovascular Atlas</span>
        </div>
        {meta.isPlaceholder && <span className="demo-badge" title={meta.source}>DEMO DATA</span>}
      </div>

      <div className="topbar-controls">
        <MetricSelector meta={meta} />
        <ModeToggle />
      </div>

      <div className="topbar-right">
        <SearchBar />
        <AboutModal meta={meta} />
      </div>
    </header>
  )
}
