import { useMemo, useRef, useState } from 'react'
import Fuse from 'fuse.js'
import { usePlaces } from '../lib/hooks'
import { useStore } from '../store'
import type { GeoMode } from '../lib/types'

interface Result {
  kind: GeoMode | 'zip'
  id: string
  primary: string
  secondary: string
  lon: number
  lat: number
}

export default function SearchBar() {
  const places = usePlaces()
  const flyTo = useStore((s) => s.flyTo)
  const setHighlight = useStore((s) => s.setHighlight)
  const mode = useStore((s) => s.mode)
  const [q, setQ] = useState('')
  const [open, setOpen] = useState(false)
  const [active, setActive] = useState(0)
  const inputRef = useRef<HTMLInputElement>(null)

  const fuse = useMemo(() => {
    if (!places) return null
    const items = [
      ...places.counties.map((c) => ({ ...c, kind: 'county' as const })),
      ...places.states.map((s) => ({ ...s, kind: 'state' as const })),
    ]
    return new Fuse(items, {
      keys: ['name', 'label', 'st'],
      threshold: 0.4,
      ignoreLocation: true,
      minMatchCharLength: 2,
    })
  }, [places])

  const results = useMemo<Result[]>(() => {
    const query = q.trim()
    if (!places || query.length < 2) return []
    // ZIP codes: direct prefix match (fast, exact).
    if (/^\d{2,5}$/.test(query)) {
      return places.zips
        .filter(([zip]) => zip.startsWith(query))
        .slice(0, 8)
        .map(([zip, lon, lat]) => ({
          kind: 'zip' as const,
          id: zip,
          primary: zip,
          secondary: 'ZIP code',
          lon,
          lat,
        }))
    }
    if (!fuse) return []
    return fuse
      .search(query, { limit: 8 })
      .map(({ item }) => ({
        kind: item.kind,
        id: item.id,
        primary: item.name,
        secondary: item.kind === 'county' ? `County · ${item.st}` : 'State',
        lon: item.lon,
        lat: item.lat,
      }))
  }, [q, fuse, places])

  function choose(r: Result) {
    const zoom = r.kind === 'zip' ? 9 : r.kind === 'county' ? 7.5 : 5.4
    flyTo(r.lon, r.lat, zoom)
    if (r.kind === 'county') setHighlight(mode === 'county' ? r.id : r.id.slice(0, 2))
    else if (r.kind === 'state') setHighlight(mode === 'state' ? r.id : null)
    else setHighlight(null)
    setQ(r.primary)
    setOpen(false)
    inputRef.current?.blur()
  }

  function onKeyDown(e: React.KeyboardEvent) {
    if (!open || results.length === 0) return
    if (e.key === 'ArrowDown') {
      e.preventDefault()
      setActive((a) => (a + 1) % results.length)
    } else if (e.key === 'ArrowUp') {
      e.preventDefault()
      setActive((a) => (a - 1 + results.length) % results.length)
    } else if (e.key === 'Enter') {
      e.preventDefault()
      choose(results[active] ?? results[0])
    } else if (e.key === 'Escape') {
      setOpen(false)
    }
  }

  return (
    <div className="search">
      <span className="search-ico" aria-hidden>
        ⌕
      </span>
      <input
        ref={inputRef}
        className="search-input"
        placeholder={places ? 'Search ZIP, county, or state…' : 'Loading places…'}
        value={q}
        disabled={!places}
        onChange={(e) => {
          setQ(e.target.value)
          setOpen(true)
          setActive(0)
        }}
        onFocus={() => setOpen(true)}
        onBlur={() => setTimeout(() => setOpen(false), 120)}
        onKeyDown={onKeyDown}
      />
      {q && (
        <button
          className="search-clear"
          onMouseDown={(e) => e.preventDefault()}
          onClick={() => {
            setQ('')
            setHighlight(null)
            inputRef.current?.focus()
          }}
          aria-label="Clear search"
        >
          ✕
        </button>
      )}
      {open && results.length > 0 && (
        <ul className="search-results glass">
          {results.map((r, i) => (
            <li
              key={`${r.kind}-${r.id}`}
              className={i === active ? 'active' : ''}
              onMouseDown={(e) => {
                e.preventDefault()
                choose(r)
              }}
              onMouseEnter={() => setActive(i)}
            >
              <span className={`res-kind ${r.kind}`}>{r.kind === 'zip' ? 'ZIP' : r.kind}</span>
              <span className="res-primary">{r.primary}</span>
              <span className="res-secondary">{r.secondary}</span>
            </li>
          ))}
        </ul>
      )}
    </div>
  )
}
