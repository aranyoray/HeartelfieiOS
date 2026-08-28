import { Component } from 'react'
import type { ErrorInfo, ReactNode } from 'react'
import { SUPPORT_EMAIL } from '../pages/DocLayout'

interface Props {
  children: ReactNode
}

interface State {
  error: Error | null
}

export default class ErrorBoundary extends Component<Props, State> {
  state: State = { error: null }

  static getDerivedStateFromError(error: Error): State {
    return { error }
  }

  componentDidCatch(error: Error, info: ErrorInfo) {
    if (typeof console !== 'undefined') console.error('DailyDil crashed:', error, info)
  }

  render() {
    if (!this.state.error) return this.props.children
    return (
      <div className="boot" role="alert">
        <div className="boot-pulse" />
        <strong>DailyDil hit an unexpected error.</strong>
        <span style={{ maxWidth: 420, textAlign: 'center', lineHeight: 1.5 }}>
          Try reloading the page. If the problem keeps happening, email{' '}
          <a href={`mailto:${SUPPORT_EMAIL}`}>{SUPPORT_EMAIL}</a> and include what you were doing.
        </span>
        <button
          className="mode-pill"
          style={{ marginTop: 4 }}
          onClick={() => {
            this.setState({ error: null })
            if (typeof window !== 'undefined') window.location.reload()
          }}
        >
          Reload
        </button>
      </div>
    )
  }
}
