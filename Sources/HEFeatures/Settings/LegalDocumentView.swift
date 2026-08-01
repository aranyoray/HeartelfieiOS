import SwiftUI
import HECore
import HEDesign

/// A legal / policy document the app can display in a fully self-contained,
/// offline screen. Keeping the text in-app (rather than only behind a web link)
/// guarantees users — and App Review — can always reach the privacy policy and
/// terms, with no dependency on a live URL.
public enum LegalDocument: String, Hashable, Sendable, Identifiable, CaseIterable {
    case privacyPolicy
    case termsOfUse
    case acknowledgements

    public var id: String { rawValue }

    /// Support contact surfaced at the foot of each document.
    static let supportEmail = "support@heartelfie.app"

    var title: String {
        switch self {
        case .privacyPolicy: return "Privacy Policy"
        case .termsOfUse: return "Terms of Use"
        case .acknowledgements: return "Acknowledgements"
        }
    }

    var lastUpdated: String? {
        switch self {
        case .privacyPolicy: return "August 1, 2026"
        case .termsOfUse: return "August 1, 2026"
        case .acknowledgements: return nil
        }
    }

    var intro: String {
        switch self {
        case .privacyPolicy:
            return "This Privacy Policy explains how the Heartelfie app handles information. Heartelfie is a wellness screening app, not a medical device, and is not intended to diagnose, treat, cure, or prevent any disease or condition."
        case .termsOfUse:
            return "These Terms of Use govern your use of the Heartelfie app. By using Heartelfie you agree to these Terms. If you do not agree, please do not use the app."
        case .acknowledgements:
            return "Heartelfie is built with the following open resources and standards."
        }
    }

    var sections: [LegalSection] {
        switch self {
        case .privacyPolicy: return Self.privacySections
        case .termsOfUse: return Self.termsSections
        case .acknowledgements: return Self.acknowledgementSections
        }
    }

    // MARK: - Privacy Policy (mirrors the published web policy)

    private static let privacySections: [LegalSection] = [
        LegalSection(heading: "1. Summary", bullets: [
            "Heartelfie does not require an account, name, email, or password.",
            "Readings and optional profile values are stored locally on your device.",
            "Camera frames, including face frames, are processed on device and are not saved.",
            "Face data is not sold, used for advertising, or shared with third parties.",
            "Apple Health / HealthKit access is optional and controlled by the Health app.",
            "Heartelfie does not use advertising SDKs or third-party tracking analytics."
        ]),
        LegalSection(heading: "2. Information Processed by the App",
            body: "Heartelfie may process camera, Bluetooth, notification, Apple Health, and optional profile information only when you choose features that need those capabilities. The optional profile may include values such as age, biological sex, height, weight, general health context, units, and self-selected Monk Skin Tone. These values are used to personalize wellness screening context and improve signal-quality handling."),
        LegalSection(heading: "3. Face Data",
            body: "During a facial rPPG check, Heartelfie uses the front camera video stream to locate a face region and process subtle color changes that can be used to estimate pulse for a wellness screening. This is the only face data collected by the app. Heartelfie does not create Face ID templates, does not identify you, and does not use face data for authentication, advertising, profiling, or tracking. Raw face images and video frames are processed in memory on the device. They are not saved to the app database, not written to Apple Health, not uploaded to Heartelfie servers, and not shared with third parties. After the check ends, raw face frames are discarded."),
        LegalSection(heading: "4. Storage, Retention, and Deletion",
            body: "Heartelfie stores readings and optional profile values locally on your device in an encrypted database, with encryption keys stored in the iOS Keychain. Raw camera frames are retained only in memory during processing and are discarded immediately after the check. Derived readings remain on your device until you delete them, export them, or remove the app. You can delete local Heartelfie data from the app's Data & Privacy screen."),
        LegalSection(heading: "5. Apple Health / HealthKit",
            body: "Apple Health integration is optional. With your permission, Heartelfie may read supported Apple Health values such as heart rate, heart-rate variability, resting heart rate, oxygen wellness, and breathing rate. With your permission, Heartelfie may write supported reading summaries back to Apple Health. Face frames, custom waveforms, and device-only wellness estimates are not written to HealthKit. You can change Apple Health permissions at any time in the Health app."),
        LegalSection(heading: "6. Sharing and Third Parties",
            body: "Heartelfie does not sell personal information or face data. We do not share face data with third parties. We do not use advertising SDKs, third-party tracking analytics, or cross-app tracking. If you export a CSV or PDF, you choose where that exported file goes outside Heartelfie."),
        LegalSection(heading: "7. Children's Privacy",
            body: "Heartelfie is not directed to children under 13, and we do not knowingly collect personal information from children."),
        LegalSection(heading: "8. Your Rights",
            body: "Depending on where you live, you may have rights to access, correct, or delete personal data a company holds about you. Most Heartelfie data is stored only on your device, so you can delete it directly in the app. If you have questions about privacy rights, contact us using the details below."),
        LegalSection(heading: "9. Security",
            body: "Heartelfie uses on-device processing where practical, local encrypted storage for readings, and iOS Keychain storage for encryption keys. No method of storage is completely secure, but Heartelfie minimizes risk by avoiding account creation and avoiding storage of raw face frames."),
        LegalSection(heading: "10. Medical Disclaimer",
            body: "Heartelfie is provided for wellness and informational purposes only. It is not medical advice and does not diagnose, treat, or make care recommendations based on any reading. If you think you may be having a medical emergency, contact local emergency services."),
        LegalSection(heading: "11. Changes to This Policy",
            body: "We may update this Privacy Policy from time to time. When we do, we will revise the \"Last updated\" date at the top of this page.")
    ]

    // MARK: - Terms of Use (written for this app)

    private static let termsSections: [LegalSection] = [
        LegalSection(heading: "1. What Heartelfie Is",
            body: "Heartelfie is a consumer wellness app that provides heart-related screening insights from your device's camera and, optionally, from separate Heartelfie hardware. Heartelfie is not a medical device and does not provide medical care."),
        LegalSection(heading: "2. Not Medical Advice",
            body: "Heartelfie does not provide medical advice, diagnosis, or treatment. All readings are wellness and screening insights only and are not a substitute for professional medical advice. Always seek the advice of a qualified healthcare professional with any questions about a medical condition. Never disregard professional medical advice or delay seeking it because of something you have seen in Heartelfie. If you think you may have a medical emergency, call your local emergency number immediately."),
        LegalSection(heading: "3. Screening, Not Measurement",
            body: "Phone-based checks are screenings, not medical measurements, and are lower confidence by nature. Results can be affected by lighting, movement, skin contact, and other conditions. Treat readings as trends to observe over time, not as conclusions to act on."),
        LegalSection(heading: "4. No Warranties",
            body: "Heartelfie is provided \"AS IS\" and \"AS AVAILABLE\", without warranties of any kind, whether express or implied, including the implied warranties of merchantability, fitness for a particular purpose, non-infringement, accuracy, or availability. We do not warrant that Heartelfie will be uninterrupted, error-free, or that any reading is accurate or complete."),
        LegalSection(heading: "5. Limitation of Liability",
            body: "To the maximum extent permitted by law, in no event will the developers or operators of Heartelfie be liable for any indirect, incidental, special, consequential, or punitive damages, or for any loss of data, arising out of or relating to your use of (or inability to use) Heartelfie. Some jurisdictions do not allow certain limitations, so some of the above may not apply to you."),
        LegalSection(heading: "6. Acceptable Use", bullets: [
            "Do not use Heartelfie to make diagnostic, clinical, or insurance decisions.",
            "Do not attempt to disrupt or reverse engineer the app.",
            "Comply with all laws applicable to your use of the app."
        ]),
        LegalSection(heading: "7. Changes to These Terms",
            body: "We may update these Terms from time to time. When we do, we will revise the \"Last updated\" date at the top of this page. Your continued use of Heartelfie after changes are posted constitutes acceptance of the updated Terms.")
    ]

    // MARK: - Acknowledgements

    private static let acknowledgementSections: [LegalSection] = [
        LegalSection(heading: "Design & platform",
            body: "Built with Apple SwiftUI, HealthKit, Core Bluetooth, and CryptoKit. Skin-tone options use the 10-point Monk Skin Tone scale."),
        LegalSection(heading: "Signal processing",
            body: "Bandpass filtering uses the well-known RBJ \"Audio EQ Cookbook\" biquad formulas. Screening estimates are derived on device from standard photoplethysmography techniques.")
    ]
}

/// A single titled section of a legal document.
struct LegalSection: Hashable {
    var heading: String?
    var body: String = ""
    var bullets: [String] = []
}

/// Renders a `LegalDocument` as scrollable, accessible, Dynamic-Type-friendly copy.
struct LegalDocumentView: View {
    let document: LegalDocument

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HESpacing.lg) {
                if let updated = document.lastUpdated {
                    Text("Last updated \(updated)")
                        .font(.heCaption)
                        .foregroundStyle(Color.heTextTertiary)
                }

                Text(document.intro)
                    .font(.heBody)
                    .foregroundStyle(Color.heTextPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                ForEach(Array(document.sections.enumerated()), id: \.offset) { item in
                    sectionView(item.element)
                }

                contactCard
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(HESpacing.md)
        }
        .background(Color.heBackground)
        .navigationTitle(document.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func sectionView(_ section: LegalSection) -> some View {
        VStack(alignment: .leading, spacing: HESpacing.sm) {
            if let heading = section.heading {
                Text(heading)
                    .font(.heHeadline)
                    .foregroundStyle(Color.heTextPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !section.body.isEmpty {
                Text(section.body)
                    .font(.heCallout)
                    .foregroundStyle(Color.heTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            ForEach(section.bullets, id: \.self) { bullet in
                HStack(alignment: .top, spacing: HESpacing.sm) {
                    Text("•")
                        .font(.heCallout)
                        .foregroundStyle(Color.heTextTertiary)
                        .accessibilityHidden(true)
                    Text(bullet)
                        .font(.heCallout)
                        .foregroundStyle(Color.heTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var contactCard: some View {
        VStack(alignment: .leading, spacing: HESpacing.xs) {
            Text("Contact")
                .font(.heHeadline)
                .foregroundStyle(Color.heTextPrimary)
            if let url = URL(string: "mailto:\(LegalDocument.supportEmail)") {
                Link(destination: url) {
                    Text(LegalDocument.supportEmail)
                        .font(.heCallout.weight(.medium))
                        .foregroundStyle(Color.hePrimary)
                }
                .accessibilityLabel("Email support at \(LegalDocument.supportEmail)")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, HESpacing.sm)
    }
}

#Preview("Privacy Policy") {
    NavigationStack { LegalDocumentView(document: .privacyPolicy) }
}

#Preview("Terms of Use") {
    NavigationStack { LegalDocumentView(document: .termsOfUse) }
}
