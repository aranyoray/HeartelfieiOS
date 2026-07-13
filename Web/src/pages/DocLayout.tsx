import { useEffect } from 'react'
import { Link, useLocation } from 'react-router-dom'
import type { ReactNode } from 'react'

// Placeholder support contact — replace with your real, monitored support
// address before App Store / Play Store submission (Apple requires a working
// support URL + contact).
export const SUPPORT_EMAIL = 'support@heartelfie.app'

export default function DocLayout({
  title,
  updated,
  children,
}: {
  title: string
  updated: string
  children: ReactNode
}) {
  const { pathname } = useLocation()
  useEffect(() => {
    if (typeof window !== 'undefined') window.scrollTo(0, 0)
  }, [pathname])

  return (
    <div className="doc-page">
      <header className="doc-header">
        <Link to="/" className="doc-brand">
          <span className="brand-pulse" aria-hidden />
          <span>Heartelfie</span>
        </Link>
        <nav className="doc-nav">
          <Link to="/">Atlas</Link>
          <Link to="/privacy">Privacy</Link>
          <Link to="/support">Support</Link>
          <Link to="/terms">Terms</Link>
        </nav>
      </header>

      <main className="doc">
        <h1>{title}</h1>
        <p className="doc-updated">Last updated: {updated}</p>
        {children}
        <footer className="doc-footer">
          <p>
            Heartelfie · U.S. Heart & Circulatory Wellness Atlas · Questions?{' '}
            <a href={`mailto:${SUPPORT_EMAIL}`}>{SUPPORT_EMAIL}</a>
          </p>
          <p className="doc-footer-disclaimer">
            For information and education only — <strong>not medical advice</strong>. Figures
            describe geographic areas, never individuals. Always consult a qualified healthcare
            professional for medical concerns.
          </p>
          <p>
            <Link to="/">Back to the atlas</Link> · <Link to="/privacy">Privacy</Link> ·{' '}
            <Link to="/support">Support</Link> · <Link to="/terms">Terms</Link>
          </p>
        </footer>
      </main>
    </div>
  )
}
