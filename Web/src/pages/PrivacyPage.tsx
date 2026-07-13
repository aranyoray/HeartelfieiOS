import DocLayout, { SUPPORT_EMAIL } from './DocLayout'

export default function PrivacyPage() {
  return (
    <DocLayout title="Privacy Policy" updated="July 5, 2026">
      <p>
        This Privacy Policy explains how the Heartelfie application and website (“Heartelfie”, “the
        app”, “we”, “us”) handle information when you use it. Heartelfie is an interactive map that
        visualizes <strong>publicly available, aggregated</strong> population-health statistics. Our
        guiding principle is simple: <strong>we do not collect personal information about you.</strong>
      </p>

      <h2>1. Summary</h2>
      <ul>
        <li>We do <strong>not</strong> require an account, name, email, or password to use Heartelfie.</li>
        <li>We do <strong>not</strong> collect, store, or sell personal or health information about you.</li>
        <li>We do <strong>not</strong> use advertising SDKs or third-party tracking/analytics.</li>
        <li>Search queries and map interactions are processed <strong>on your device</strong>.</li>
        <li>
          The health figures shown describe <strong>geographic areas</strong> (counties and states),
          never individuals.
        </li>
      </ul>

      <h2>2. Information We Do Not Collect</h2>
      <p>
        Heartelfie does not ask for or collect personally identifiable information. We do not collect
        your name, email address, phone number, contacts, photos, precise GPS location, health
        records, or device identifiers for tracking. We do not build advertising profiles and we do
        not fingerprint your device.
      </p>

      <h2>3. Information Processed Locally on Your Device</h2>
      <p>
        When you search for a ZIP code, county, or state, that text is matched against a dataset
        bundled with the app <strong>on your device</strong>. It is not transmitted to us. The app
        may store small, non-identifying interface preferences (for example, the last selected
        metric or 3D height setting) in your browser’s local storage so the app remembers them.
        You can clear this at any time by clearing your browser/app storage.
      </p>

      <h2>4. Network and Hosting</h2>
      <p>
        Heartelfie loads its map geometry and data files over the internet from our hosting/content
        provider. Like virtually all websites, our hosting provider may automatically process basic
        technical request information (such as IP address, timestamp, and user-agent) in server logs
        for security, abuse-prevention, and reliable content delivery. We do not use this
        information to identify you and we do not combine it with any other data to build a profile.
      </p>

      <h2>5. Cookies and Similar Technologies</h2>
      <p>
        Heartelfie does not use advertising or cross-site tracking cookies. Any browser storage used is
        strictly functional (remembering your in-app preferences) and stays on your device.
      </p>

      <h2>6. Data Sources</h2>
      <p>
        Health measures are derived from the U.S. Centers for Disease Control and Prevention (CDC)
        “PLACES” program, which publishes model-based, small-area estimates of chronic-disease
        prevalence. Geographic boundaries are derived from U.S. Census Bureau cartographic files.
        These are <strong>aggregate, public datasets</strong> about places — not about you. Learn
        more at{' '}
        <a href="https://www.cdc.gov/places/" target="_blank" rel="noreferrer">
          cdc.gov/places
        </a>
        .
      </p>

      <h2>7. Children’s Privacy</h2>
      <p>
        Heartelfie is a general-audience informational tool and is not directed to children under 13.
        We do not knowingly collect personal information from children. Because we do not collect
        personal information from anyone, this applies to all users.
      </p>

      <h2>8. Your Rights</h2>
      <p>
        Depending on where you live (for example, under the EU/UK GDPR or the California Consumer
        Privacy Act), you may have rights to access, correct, or delete personal data a company holds
        about you. Because Heartelfie does not collect personal information, we generally have no such
        data to access, correct, or delete. If you have a question about your privacy rights, contact
        us using the details below.
      </p>

      <h2>9. Security</h2>
      <p>
        We serve the app over encrypted connections (HTTPS). While no method of transmission is ever
        100% secure, the app’s no-collection design minimizes privacy risk by avoiding personal data
        altogether.
      </p>

      <h2>10. Medical Disclaimer</h2>
      <p>
        Heartelfie is provided for informational and educational purposes only and is not medical
        advice. It does not diagnose, treat, or make recommendations about any individual’s health.
        Always consult a qualified healthcare professional for medical concerns.
      </p>

      <h2>11. Changes to This Policy</h2>
      <p>
        We may update this Privacy Policy from time to time. When we do, we will revise the “Last
        updated” date at the top of this page. Material changes will be reflected here.
      </p>

      <h2>12. Contact Us</h2>
      <p>
        If you have any questions about this Privacy Policy or Heartelfie, contact us at{' '}
        <a href={`mailto:${SUPPORT_EMAIL}`}>{SUPPORT_EMAIL}</a>.
      </p>
    </DocLayout>
  )
}
