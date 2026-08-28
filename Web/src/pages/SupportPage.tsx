import DocLayout, { SUPPORT_EMAIL } from './DocLayout'

export default function SupportPage() {
  return (
    <DocLayout title="Support & Help" updated="July 5, 2026">
      <p>
        Need help with DailyDil, found a bug, or have a feature idea? We’re happy to hear from you.
      </p>

      <div className="support-contact">
        <div>
          <span className="support-label">Email support</span>
          <a className="support-email" href={`mailto:${SUPPORT_EMAIL}`}>
            {SUPPORT_EMAIL}
          </a>
        </div>
        <p className="support-response">
          We typically respond within <strong>2–3 business days</strong>. To help us help you
          faster, please include your device and operating system (e.g., “iPhone 15, iOS 18”), your
          browser if applicable, and a short description or screenshot of the issue.
        </p>
      </div>

      <h2>About DailyDil</h2>
      <p>
        DailyDil is an interactive atlas of U.S. heart &amp; circulatory wellness awareness. Each
        county or state is colored by a community-level, age-adjusted wellness-awareness indicator —{' '}
        <strong>Circulatory Strain</strong>, <strong>Heart Health</strong>, or{' '}
        <strong>Brain Circulation</strong> — redder means a higher community indicator — on a map you
        can tilt and rotate for a perspective view, so you can see geographic patterns and how they
        change over time.
      </p>

      <h2>Getting Started</h2>
      <ul>
        <li>
          <strong>Pick a metric</strong> — switch between Circulatory, Heart, and Brain at the top.
        </li>
        <li>
          <strong>Counties or States</strong> — toggle the geography level at the top.
        </li>
        <li>
          <strong>Move through time</strong> — drag the year slider, or press play to animate the
          years.
        </li>
        <li>
          <strong>Compare two years</strong> — tap “Compare years” to view two years side by side
          with a synced camera.
        </li>
        <li>
          <strong>Search</strong> — type a ZIP code, county, or state to zoom straight to it.
        </li>
        <li>
          <strong>Compare areas</strong> — click up to three counties/states (or search and click)
          to chart their trends in the panel at the bottom.
        </li>
        <li>
          <strong>Tilt &amp; rotate</strong> — right-drag (or two-finger drag on touch) to view the
          map at an angle; drag normally to pan.
        </li>
      </ul>

      <h2>Frequently Asked Questions</h2>

      <h3>Where does the data come from?</h3>
      <p>
        Health measures come from the U.S. CDC <strong>PLACES</strong> program — model-based,
        small-area estimates of chronic-disease prevalence derived from the Behavioral Risk Factor
        Surveillance System (BRFSS). County and state boundaries come from the U.S. Census Bureau.
        See{' '}
        <a href="https://www.cdc.gov/places/" target="_blank" rel="noreferrer">
          cdc.gov/places
        </a>
        .
      </p>

      <h3>What does “age-adjusted” mean?</h3>
      <p>
        Age-adjusted prevalence statistically removes differences in the age makeup of each area, so
        you can compare places fairly even when one has an older or younger population than another.
      </p>

      <h3>Why is a county missing or greyed out?</h3>
      <p>
        A small number of areas may lack a published estimate for a given measure or year; those
        appear muted with “No data” on hover. DailyDil covers the 50 states and the District of
        Columbia.
      </p>

      <h3>Can I rely on these numbers for medical decisions?</h3>
      <p>
        No. DailyDil is for information and education only and is not medical advice. These are
        area-level estimates, not measurements of any individual. Consult a healthcare professional
        for personal health questions.
      </p>

      <h2>Troubleshooting</h2>
      <ul>
        <li>
          <strong>Map is blank or won’t load:</strong> ensure hardware acceleration / WebGL is
          enabled and your browser or app is up to date, then reload.
        </li>
        <li>
          <strong>Choppy performance:</strong> switch to the States view, make the browser window
          smaller, or close other heavy tabs/apps.
        </li>
        <li>
          <strong>Search isn’t finding a place:</strong> try the 5-digit ZIP, or the county name
          plus state (e.g., “Travis, TX”).
        </li>
        <li>
          <strong>Something looks stuck:</strong> fully close and reopen the app, or clear the site’s
          cached storage.
        </li>
      </ul>

      <h2>Accessibility &amp; Feedback</h2>
      <p>
        We want DailyDil to work well for everyone. If you encounter an accessibility barrier or have
        a suggestion, please email{' '}
        <a href={`mailto:${SUPPORT_EMAIL}`}>{SUPPORT_EMAIL}</a> and we’ll do our best to address it.
      </p>
    </DocLayout>
  )
}
