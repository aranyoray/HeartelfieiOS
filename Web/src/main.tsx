import { createRoot } from 'react-dom/client'
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom'
import App from './App'
import PrivacyPage from './pages/PrivacyPage'
import SupportPage from './pages/SupportPage'
import TermsPage from './pages/TermsPage'
import ErrorBoundary from './components/ErrorBoundary'
import './index.css'

// NOTE: StrictMode intentionally omitted — its dev-only double-mount conflicts
// with deck.gl's single WebGL context. Production behaviour is unaffected.
createRoot(document.getElementById('root')!).render(
  <BrowserRouter>
    <ErrorBoundary>
      <Routes>
        <Route path="/" element={<App />} />
        <Route path="/privacy" element={<PrivacyPage />} />
        <Route path="/support" element={<SupportPage />} />
        <Route path="/terms" element={<TermsPage />} />
        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    </ErrorBoundary>
  </BrowserRouter>,
)
