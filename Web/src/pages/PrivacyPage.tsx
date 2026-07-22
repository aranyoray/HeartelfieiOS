import DocLayout, { SUPPORT_EMAIL } from './DocLayout'

export default function PrivacyPage() {
  return (
    <DocLayout title="Privacy Policy" updated="July 22, 2026">
      <p>
        This Privacy Policy explains how the Heartelfie iOS app and website (“Heartelfie”, “the
        app”, “we”, “us”) handle information. Heartelfie is a wellness screening app, not a
        medical device, and is not intended to diagnose, treat, cure, or prevent any disease or
        condition.
      </p>

      <h2>1. Summary</h2>
      <ul>
        <li>Heartelfie does not require an account, name, email, or password.</li>
        <li>Readings and optional profile values are stored locally on your device.</li>
        <li>Camera frames, including face frames, are processed on device and are not saved.</li>
        <li>Face data is not sold, used for advertising, or shared with third parties.</li>
        <li>Apple Health / HealthKit access is optional and controlled by the Health app.</li>
        <li>Heartelfie does not use advertising SDKs or third-party tracking analytics.</li>
      </ul>

      <h2>2. Information Processed by the App</h2>
      <p>
        Heartelfie may process camera, microphone, motion, Bluetooth, notification, Apple Health,
        and optional profile information only when you choose features that need those capabilities.
        The optional profile may include values such as age range, biological sex, height, weight,
        general health context, units, and self-selected Monk Skin Tone. These values are used to
        personalize wellness screening context and improve signal-quality handling.
      </p>

      <h2>3. Face Data</h2>
      <p>
        During a facial rPPG check, Heartelfie uses the front camera video stream to locate a face
        region and process subtle color changes that can be used to estimate pulse for a wellness
        screening. This is the only face data collected by the app. Heartelfie does not create Face
        ID templates, does not identify you, and does not use face data for authentication,
        advertising, profiling, or tracking.
      </p>
      <p>
        Raw face images and video frames are processed in memory on the device. They are not saved
        to the app database, not written to Apple Health, not uploaded to Heartelfie servers, and not
        shared with third parties. After the check ends, raw face frames are discarded. The saved
        reading may include derived wellness metrics, signal-quality values, timestamps, capture
        modality, model provenance, and a small derived waveform preview.
      </p>

      <h2>4. Storage, Retention, and Deletion</h2>
      <p>
        Heartelfie stores readings and optional profile values locally on your device in an
        encrypted database, with encryption keys stored in the iOS Keychain. Raw camera frames,
        including raw face frames, are retained only in memory during processing and are discarded
        immediately after the check. Derived readings remain on your device until you delete them,
        export them, or remove the app. You can delete local Heartelfie data from the app’s Data &
        Privacy screen.
      </p>

      <h2>5. Apple Health / HealthKit</h2>
      <p>
        Apple Health integration is optional. With your permission, Heartelfie may read supported
        Apple Health values such as heart rate, heart-rate variability, resting heart rate, oxygen
        wellness, breathing rate, and available Apple Watch rhythm data. With your permission,
        Heartelfie may write supported reading summaries back to Apple Health. Face frames, custom
        waveforms, and device-only wellness estimates are not written to HealthKit. You can change
        Apple Health permissions at any time in the Health app.
      </p>

      <h2>6. Sharing and Third Parties</h2>
      <p>
        Heartelfie does not sell personal information or face data. We do not share face data with
        third parties. We do not use advertising SDKs, third-party tracking analytics, or
        cross-app tracking. If you export a CSV or PDF, you choose where that exported file goes
        outside Heartelfie.
      </p>

      <h2>7. Network and Hosting</h2>
      <p>
        The iOS app is designed to process sensitive signals on device. The website may load static
        files over the internet from our hosting/content provider. Like most websites, our hosting
        provider may automatically process basic technical request information such as IP address,
        timestamp, and user-agent in server logs for security, abuse prevention, and reliable
        content delivery.
      </p>

      <h2>8. Children’s Privacy</h2>
      <p>
        Heartelfie is not directed to children under 13, and we do not knowingly collect personal
        information from children.
      </p>

      <h2>9. Your Rights</h2>
      <p>
        Depending on where you live, you may have rights to access, correct, or delete personal data
        a company holds about you. Most Heartelfie data is stored only on your device, so you can
        delete it directly in the app. If you have questions about privacy rights, contact us using
        the details below.
      </p>

      <h2>10. Security</h2>
      <p>
        Heartelfie uses on-device processing where practical, local encrypted storage for readings,
        iOS Keychain storage for encryption keys, and encrypted network connections for web content.
        No method of storage or transmission is completely secure, but Heartelfie minimizes risk by
        avoiding account creation and avoiding storage of raw face frames.
      </p>

      <h2>11. Medical Disclaimer</h2>
      <p>
        Heartelfie is provided for wellness and informational purposes only. It is not medical
        advice and does not diagnose, treat, or make care recommendations based on any reading. If
        you think you may be having a medical emergency, contact local emergency services.
      </p>

      <h2>12. Changes to This Policy</h2>
      <p>
        We may update this Privacy Policy from time to time. When we do, we will revise the “Last
        updated” date at the top of this page.
      </p>

      <h2>13. Contact Us</h2>
      <p>
        If you have any questions about this Privacy Policy or Heartelfie, contact us at{' '}
        <a href={`mailto:${SUPPORT_EMAIL}`}>{SUPPORT_EMAIL}</a>.
      </p>
    </DocLayout>
  )
}
