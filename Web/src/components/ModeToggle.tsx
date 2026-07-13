import { useStore } from '../store'

export default function ModeToggle() {
  const mode = useStore((s) => s.mode)
  const setMode = useStore((s) => s.setMode)
  return (
    <div className="segmented" role="tablist" aria-label="Geography level">
      <button
        role="tab"
        aria-selected={mode === 'county'}
        className={mode === 'county' ? 'seg active' : 'seg'}
        onClick={() => setMode('county')}
      >
        Counties
      </button>
      <button
        role="tab"
        aria-selected={mode === 'state'}
        className={mode === 'state' ? 'seg active' : 'seg'}
        onClick={() => setMode('state')}
      >
        States
      </button>
    </div>
  )
}
