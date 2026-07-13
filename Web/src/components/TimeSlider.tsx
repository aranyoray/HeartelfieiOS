import { useEffect } from 'react'
import { useStore } from '../store'

const PLAY_MS = 950

export default function TimeSlider({ years }: { years: number[] }) {
  const year = useStore((s) => s.year)
  const setYear = useStore((s) => s.setYear)
  const compare = useStore((s) => s.compare)
  const setCompare = useStore((s) => s.setCompare)
  const yearLeft = useStore((s) => s.yearLeft)
  const yearRight = useStore((s) => s.yearRight)
  const setYearLeft = useStore((s) => s.setYearLeft)
  const setYearRight = useStore((s) => s.setYearRight)
  const playing = useStore((s) => s.playing)
  const setPlaying = useStore((s) => s.setPlaying)

  const idx = Math.max(0, years.indexOf(year))
  const min = years[0]
  const max = years[years.length - 1]

  useEffect(() => {
    if (!playing || compare) return
    const t = setInterval(() => {
      const cur = useStore.getState().year
      const i = years.indexOf(cur)
      const next = years[(i + 1) % years.length]
      useStore.getState().setYear(next)
    }, PLAY_MS)
    return () => clearInterval(t)
  }, [playing, compare, years])

  return (
    <div className="time-bar glass">
      <button
        className={`mode-pill ${compare ? 'active' : ''}`}
        onClick={() => setCompare(!compare)}
        title="Compare two years side by side"
      >
        <span className="split-ico" /> Compare years
      </button>

      {!compare ? (
        <>
          <button
            className="play-btn"
            onClick={() => setPlaying(!playing)}
            aria-label={playing ? 'Pause' : 'Play through years'}
          >
            {playing ? '❚❚' : '▶'}
          </button>
          <span className="year-big">{year}</span>
          <input
            className="year-range"
            type="range"
            min={0}
            max={years.length - 1}
            step={1}
            value={idx}
            onChange={(e) => {
              setPlaying(false)
              setYear(years[Number(e.target.value)])
            }}
            list="yearticks"
          />
          <datalist id="yearticks">
            {years.map((y) => (
              <option key={y} value={years.indexOf(y)} />
            ))}
          </datalist>
          <span className="year-range-bounds">
            {min}–{max}
          </span>
        </>
      ) : (
        <div className="year-ab">
          <label>
            <span className="ab-tag a">A</span>
            <select value={yearLeft} onChange={(e) => setYearLeft(Number(e.target.value))}>
              {years.map((y) => (
                <option key={y} value={y}>
                  {y}
                </option>
              ))}
            </select>
          </label>
          <span className="vs">vs</span>
          <label>
            <span className="ab-tag b">B</span>
            <select value={yearRight} onChange={(e) => setYearRight(Number(e.target.value))}>
              {years.map((y) => (
                <option key={y} value={y}>
                  {y}
                </option>
              ))}
            </select>
          </label>
        </div>
      )}
    </div>
  )
}
