import { useEffect, useId, useState } from 'react'
import { Link } from 'react-router-dom'
import type { Meta } from '../lib/types'

export default function AboutModal({ meta }: { meta: Meta }) {
  const [open, setOpen] = useState(false)
  const titleId = useId()

  useEffect(() => {
    if (!open) return
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') setOpen(false)
    }
    const prevOverflow = document.body.style.overflow
    document.body.style.overflow = 'hidden'
    window.addEventListener('keydown', onKey)
    return () => {
      window.removeEventListener('keydown', onKey)
      document.body.style.overflow = prevOverflow
    }
  }, [open])

  return (
    <>
      <button
        className="icon-btn"
        title="About & data sources"
        aria-label="About DailyDil and data sources"
        onClick={() => setOpen(true)}
      >
        ⓘ
      </button>
      {open && (
        <div className="modal-backdrop" onClick={() => setOpen(false)}>
          <div
            className="modal glass"
            role="dialog"
            aria-modal="true"
            aria-labelledby={titleId}
            onClick={(e) => e.stopPropagation()}
          >
            <button className="modal-close" onClick={() => setOpen(false)} aria-label="Close">
              ✕
            </button>
            <h2 id={titleId}>DailyDil</h2>
            <p className="modal-tag">
              An interactive 3D atlas of U.S. heart &amp; circulatory wellness awareness by county
              and state.
            </p>

            {meta.isPlaceholder && (
              <div className="modal-warn" role="note">
                <strong>Demo data.</strong> The map currently shows <em>synthetic placeholder</em>{' '}
                values in the exact CDC PLACES schema so every feature works. Run{' '}
                <code>npm run data:scrape</code> after allowlisting <code>data.cdc.gov</code> to
                load real CDC numbers — no code changes needed. <strong>Do not cite</strong> these
                figures.
              </div>
            )}

            <h3>How to read it</h3>
            <ul>
              <li>
                Each county/state is <strong>shaded by its wellness indicator</strong> on a
                pink→red ramp — redder means a higher community indicator for the area.
              </li>
              <li>
                Hover for exact values; drag to pan and right-drag (or two-finger drag) to tilt
                &amp; rotate the map.
              </li>
              <li>Use the time slider, or “Compare years” for a side-by-side of two years.</li>
              <li>Click up to 3 areas (or search) to chart their trend over time.</li>
            </ul>

            <h3>Data</h3>
            <p>
              Measures are age-adjusted, community-level heart &amp; circulatory wellness-awareness
              indicators for adults aged ≥18 from{' '}
              <a href={meta.sourceUrl} target="_blank" rel="noreferrer">
                CDC PLACES
              </a>{' '}
              (model-based small-area estimates derived from BRFSS). They describe geographic areas,
              never individuals. Geometry from the U.S. Census (via <code>us-atlas</code>).
            </p>
            <p className="modal-src">{meta.source}</p>
            {meta.notes?.length > 0 && (
              <ul className="modal-notes">
                {meta.notes.map((n) => (
                  <li key={n}>{n}</li>
                ))}
              </ul>
            )}

            <div className="modal-warn modal-warn-med" role="note">
              <strong>Not medical advice.</strong> DailyDil is for information and education only.
              Figures describe geographic areas, never individuals. Consult a qualified healthcare
              professional for any medical concern.
            </div>

            <div className="modal-foot">
              <Link to="/privacy" onClick={() => setOpen(false)}>
                Privacy
              </Link>
              <span>·</span>
              <Link to="/support" onClick={() => setOpen(false)}>
                Support
              </Link>
              <span>·</span>
              <Link to="/terms" onClick={() => setOpen(false)}>
                Terms
              </Link>
              <span className="modal-generated">Data generated {meta.generated}</span>
            </div>
          </div>
        </div>
      )}
    </>
  )
}
