import Foundation

/// Native copies of the Heartelfie Privacy Policy and Terms of Use. Kept in sync
/// with Web/src/pages/PrivacyPage.tsx and TermsPage.tsx.
extension LegalDocument {
    static let privacyPolicy = LegalDocument(
        title: "Privacy Policy",
        navTitle: "Privacy Policy",
        updated: "July 22, 2026",
        sections: [
            Section(paragraphs: [
                "This Privacy Policy explains how the Heartelfie iOS app and website (\"Heartelfie\", \"the app\", \"we\", \"us\") handle information. Heartelfie is a wellness screening app, not a medical device, and is not intended to diagnose, treat, cure, or prevent any disease or condition."
            ]),
            Section(heading: "1. Summary", bullets: [
                "Heartelfie does not require an account, name, email, or password.",
                "Readings and optional profile values are stored locally on your device.",
                "Camera frames, including face frames, are processed on device and are not saved.",
                "Face data is not sold, used for advertising, or shared with third parties.",
                "Apple Health / HealthKit access is optional and controlled by the Health app.",
                "Heartelfie does not use advertising SDKs or third-party tracking analytics."
            ]),
            Section(heading: "2. Information Processed by the App", paragraphs: [
                "Heartelfie may process camera, Bluetooth, Apple Health, and optional profile information only when you choose features that need those capabilities. The optional profile may include values such as age range, biological sex, height, weight, general health context, units, and self-selected Monk Skin Tone. These values are used to personalize wellness screening context and improve signal-quality handling."
            ]),
            Section(heading: "3. Face Data", paragraphs: [
                "During a facial rPPG check, Heartelfie uses the front camera video stream to locate a face region and process subtle color changes that can be used to estimate pulse for a wellness screening. This is the only face data collected by the app. Heartelfie does not create Face ID templates, does not identify you, and does not use face data for authentication, advertising, profiling, or tracking.",
                "Raw face images and video frames are processed in memory on the device. They are not saved to the app database, not written to Apple Health, not uploaded to Heartelfie servers, and not shared with third parties. After the check ends, raw face frames are discarded. The saved reading may include derived wellness metrics, signal-quality values, timestamps, capture modality, model provenance, and a small derived waveform preview."
            ]),
            Section(heading: "4. Storage, Retention, and Deletion", paragraphs: [
                "Heartelfie stores readings and optional profile values locally on your device in an encrypted database, with encryption keys stored in the iOS Keychain. Raw camera frames, including raw face frames, are retained only in memory during processing and are discarded immediately after the check. Derived readings remain on your device until you delete them, export them, or remove the app. You can delete local Heartelfie data from the app's Data & Privacy screen."
            ]),
            Section(heading: "5. Apple Health / HealthKit", paragraphs: [
                "Apple Health integration is optional. With your permission, Heartelfie may read supported Apple Health values such as heart rate, heart-rate variability, resting heart rate, oxygen wellness, breathing rate, and available Apple Watch rhythm data. With your permission, Heartelfie may write supported reading summaries back to Apple Health. Face frames, custom waveforms, and device-only wellness estimates are not written to HealthKit. You can change Apple Health permissions at any time in the Health app."
            ]),
            Section(heading: "6. Sharing and Third Parties", paragraphs: [
                "Heartelfie does not sell personal information or face data. We do not share face data with third parties. We do not use advertising SDKs, third-party tracking analytics, or cross-app tracking. If you export a CSV or PDF, you choose where that exported file goes outside Heartelfie."
            ]),
            Section(heading: "7. Network and Hosting", paragraphs: [
                "The iOS app is designed to process sensitive signals on device. The website may load static files over the internet from our hosting/content provider. Like most websites, our hosting provider may automatically process basic technical request information such as IP address, timestamp, and user-agent in server logs for security, abuse prevention, and reliable content delivery."
            ]),
            Section(heading: "8. Children's Privacy", paragraphs: [
                "Heartelfie is not directed to children under 13, and we do not knowingly collect personal information from children."
            ]),
            Section(heading: "9. Your Rights", paragraphs: [
                "Depending on where you live, you may have rights to access, correct, or delete personal data a company holds about you. Most Heartelfie data is stored only on your device, so you can delete it directly in the app. If you have questions about privacy rights, contact us using the details below."
            ]),
            Section(heading: "10. Security", paragraphs: [
                "Heartelfie uses on-device processing where practical, local encrypted storage for readings, iOS Keychain storage for encryption keys, and encrypted network connections for web content. No method of storage or transmission is completely secure, but Heartelfie minimizes risk by avoiding account creation and avoiding storage of raw face frames."
            ]),
            Section(heading: "11. Medical Disclaimer", paragraphs: [
                "Heartelfie is provided for wellness and informational purposes only. It is not medical advice and does not diagnose, treat, or make care recommendations based on any reading. If you think you may be having a medical emergency, contact local emergency services."
            ]),
            Section(heading: "12. Changes to This Policy", paragraphs: [
                "We may update this Privacy Policy from time to time. When we do, we will revise the \"Last updated\" date at the top of this page."
            ]),
            Section(heading: "13. Contact Us", paragraphs: [
                "If you have any questions about this Privacy Policy or Heartelfie, contact us using the link below."
            ])
        ]
    )

    static let termsOfUse = LegalDocument(
        title: "Terms of Use & Medical Disclaimer",
        navTitle: "Terms of Use",
        updated: "July 5, 2026",
        sections: [
            Section(paragraphs: [
                "These Terms of Use (\"Terms\") govern your access to and use of the Heartelfie application and website (\"Heartelfie\", \"the app\", \"we\", \"us\"). By using Heartelfie you agree to these Terms. If you do not agree, please do not use the app."
            ]),
            Section(heading: "1. What Heartelfie Is", paragraphs: [
                "Heartelfie is a wellness and screening companion for your cardiovascular wellness, and an informational tool that can visualize publicly available, aggregate U.S. population-health statistics as community-level wellness-awareness indicators. Heartelfie is not a medical device and does not provide medical care."
            ]),
            Section(heading: "2. Not Medical Advice", paragraphs: [
                "Heartelfie does not provide medical advice, diagnosis, or treatment. The content in Heartelfie is for general informational and educational purposes only and is not a substitute for professional medical advice. Always seek the advice of a qualified healthcare professional with any questions you may have regarding a medical condition. Never disregard professional medical advice or delay in seeking it because of something you have seen in Heartelfie. If you think you may have a medical emergency, call your doctor or your local emergency number immediately."
            ]),
            Section(heading: "3. Aggregate, Area-Level Data", paragraphs: [
                "Any population figures shown in Heartelfie describe geographic areas (counties and states), not individuals. They are model-based estimates derived from the U.S. CDC PLACES program (using the Behavioral Risk Factor Surveillance System, BRFSS) and are subject to the limitations of that methodology, including survey error, modeling assumptions, and revisions over time. Do not infer the health of any specific person, household, address, or ZIP code from area-level prevalence."
            ]),
            Section(heading: "4. Demo / Placeholder Data", paragraphs: [
                "When Heartelfie is built without network access to data.cdc.gov, the app ships with a clearly labeled synthetic placeholder dataset generated in the same schema as CDC PLACES. A \"DEMO DATA\" badge appears in the header in this mode. Synthetic figures are generated, not measured; they exist only so the interface is fully functional, and they must not be cited, quoted, redistributed as real statistics, or used for any decision-making."
            ]),
            Section(heading: "5. No Warranties", paragraphs: [
                "Heartelfie is provided \"AS IS\" and \"AS AVAILABLE\", without warranties of any kind, whether express or implied, including the implied warranties of merchantability, fitness for a particular purpose, non-infringement, accuracy, completeness, or availability. We do not warrant that Heartelfie will be uninterrupted, error-free, or free of harmful components, or that any data shown is current, accurate, or complete."
            ]),
            Section(heading: "6. Limitation of Liability", paragraphs: [
                "To the maximum extent permitted by law, in no event will the developers, contributors, or operators of Heartelfie be liable for any indirect, incidental, special, consequential, exemplary, or punitive damages, or for any loss of profits, revenues, data, goodwill, or other intangible losses, arising out of or relating to your use of (or inability to use) Heartelfie, even if advised of the possibility of such damages. Some jurisdictions do not allow the exclusion of certain warranties or limitations on liability, so some of the above limitations may not apply to you."
            ]),
            Section(heading: "7. Acceptable Use", bullets: [
                "Do not use Heartelfie to make individual diagnostic, clinical, or insurance decisions.",
                "Do not attempt to disrupt, scrape at abusive rates, or reverse engineer the service.",
                "Do not present synthetic placeholder values as if they were real measured statistics.",
                "Comply with all laws applicable to your use of the app."
            ]),
            Section(heading: "8. Intellectual Property", paragraphs: [
                "Source health figures are derived from the U.S. CDC PLACES program; geographic boundaries are derived from U.S. Census Bureau cartographic files — both are public-domain U.S. Government works. The Heartelfie application code, interface, and branding remain the property of their respective owners and are made available under the licenses noted in the repository."
            ]),
            Section(heading: "9. Third-Party Links", paragraphs: [
                "Heartelfie may link to third-party websites (for example, cdc.gov). We are not responsible for the content, policies, or practices of any third-party site or service."
            ]),
            Section(heading: "10. Changes to These Terms", paragraphs: [
                "We may update these Terms from time to time. When we do, we will revise the \"Last updated\" date at the top of this page. Material changes will be reflected here. Your continued use of Heartelfie after changes are posted constitutes acceptance of the updated Terms."
            ]),
            Section(heading: "11. Governing Law", paragraphs: [
                "These Terms are governed by the laws of the State of California, U.S.A., without regard to its conflict-of-laws provisions, except where superseded by mandatory local consumer-protection law."
            ]),
            Section(heading: "12. Contact", paragraphs: [
                "Questions about these Terms? Contact us using the link below."
            ])
        ]
    )
}
