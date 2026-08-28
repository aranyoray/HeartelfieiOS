import DocLayout, { SUPPORT_EMAIL } from './DocLayout'

export default function TermsPage() {
  return (
    <DocLayout title="Terms of Use & Medical Disclaimer" updated="July 5, 2026">
      <p>
        These Terms of Use (“Terms”) govern your access to and use of the DailyDil application and
        website (“DailyDil”, “the app”, “we”, “us”). By using DailyDil you agree to these Terms. If
        you do not agree, please do not use the app.
      </p>

      <h2>1. What DailyDil Is</h2>
      <p>
        DailyDil is an informational and educational tool that visualizes <strong>publicly
        available, aggregate</strong> U.S. population-health statistics as age-adjusted,
        community-level <strong>heart &amp; circulatory wellness-awareness indicators</strong> — by
        county and state. DailyDil is not a medical device and does not provide medical care.
      </p>

      <h2>2. Not Medical Advice</h2>
      <p>
        <strong>
          DailyDil does not provide medical advice, diagnosis, or treatment. The content in DailyDil
          is for general informational and educational purposes only and is not a substitute for
          professional medical advice.
        </strong>{' '}
        Always seek the advice of a qualified healthcare professional with any questions you may
        have regarding a medical condition. Never disregard professional medical advice or delay in
        seeking it because of something you have seen in DailyDil. If you think you may have a
        medical emergency, call your doctor or your local emergency number immediately.
      </p>

      <h2>3. Aggregate, Area-Level Data</h2>
      <p>
        All figures shown in DailyDil describe <strong>geographic areas</strong> (counties and
        states), not individuals. They are model-based <em>estimates</em> derived from the U.S. CDC{' '}
        <a href="https://www.cdc.gov/places/" target="_blank" rel="noreferrer">
          PLACES
        </a>{' '}
        program (using the Behavioral Risk Factor Surveillance System, BRFSS) and are subject to
        the limitations of that methodology, including survey error, modeling assumptions, and
        revisions over time. Do not infer the health of any specific person, household, address, or
        ZIP code from area-level prevalence.
      </p>

      <h2>4. Demo / Placeholder Data</h2>
      <p>
        When DailyDil is built without network access to <code>data.cdc.gov</code>, the app ships
        with a clearly labeled <strong>synthetic placeholder dataset</strong> generated in the same
        schema as CDC PLACES. A <strong>“DEMO DATA”</strong> badge appears in the header in this
        mode. Synthetic figures are <strong>generated, not measured</strong>; they exist only so the
        interface is fully functional, and they must not be cited, quoted, redistributed as real
        statistics, or used for any decision-making.
      </p>

      <h2>5. No Warranties</h2>
      <p>
        DailyDil is provided “AS IS” and “AS AVAILABLE”, without warranties of any kind, whether
        express or implied, including the implied warranties of merchantability, fitness for a
        particular purpose, non-infringement, accuracy, completeness, or availability. We do not
        warrant that DailyDil will be uninterrupted, error-free, or free of harmful components, or
        that any data shown is current, accurate, or complete.
      </p>

      <h2>6. Limitation of Liability</h2>
      <p>
        To the maximum extent permitted by law, in no event will the developers, contributors, or
        operators of DailyDil be liable for any indirect, incidental, special, consequential,
        exemplary, or punitive damages, or for any loss of profits, revenues, data, goodwill, or
        other intangible losses, arising out of or relating to your use of (or inability to use)
        DailyDil, even if advised of the possibility of such damages. Some jurisdictions do not
        allow the exclusion of certain warranties or limitations on liability, so some of the above
        limitations may not apply to you.
      </p>

      <h2>7. Acceptable Use</h2>
      <ul>
        <li>Do not use DailyDil to make individual diagnostic, clinical, or insurance decisions.</li>
        <li>Do not attempt to disrupt, scrape at abusive rates, or reverse engineer the service.</li>
        <li>Do not present synthetic placeholder values as if they were real measured statistics.</li>
        <li>Comply with all laws applicable to your use of the app.</li>
      </ul>

      <h2>8. Intellectual Property</h2>
      <p>
        Source health figures are derived from the U.S. CDC PLACES program; geographic boundaries
        are derived from U.S. Census Bureau cartographic files — both are public-domain U.S.
        Government works. The DailyDil application code, interface, and branding remain the
        property of their respective owners and are made available under the licenses noted in the
        repository.
      </p>

      <h2>9. Third-Party Links</h2>
      <p>
        DailyDil may link to third-party websites (for example, cdc.gov). We are not responsible
        for the content, policies, or practices of any third-party site or service.
      </p>

      <h2>10. Changes to These Terms</h2>
      <p>
        We may update these Terms from time to time. When we do, we will revise the “Last updated”
        date at the top of this page. Material changes will be reflected here. Your continued use
        of DailyDil after changes are posted constitutes acceptance of the updated Terms.
      </p>

      <h2>11. Governing Law</h2>
      <p>
        These Terms are governed by the laws of the State of California, U.S.A., without regard to
        its conflict-of-laws provisions, except where superseded by mandatory local consumer-
        protection law.
      </p>

      <h2>12. Contact</h2>
      <p>
        Questions about these Terms? Contact us at{' '}
        <a href={`mailto:${SUPPORT_EMAIL}`}>{SUPPORT_EMAIL}</a>.
      </p>
    </DocLayout>
  )
}
