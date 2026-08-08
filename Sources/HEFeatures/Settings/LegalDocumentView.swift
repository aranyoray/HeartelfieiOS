import SwiftUI
import HECore
import HEDesign

/// A self-contained, scrollable legal document rendered natively so the Privacy
/// Policy and Terms are always available in-app without any network dependency
/// (App Store Review Guideline 5.1.1). Content mirrors the web versions at
/// heartelfie.app; update both when the policy changes.
struct LegalDocumentView: View {
    let document: LegalDocument

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HESpacing.lg) {
                VStack(alignment: .leading, spacing: HESpacing.xxs) {
                    Text(document.title)
                        .font(.heTitle)
                        .foregroundStyle(Color.heTextPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Last updated \(document.updated)")
                        .font(.heCaption)
                        .foregroundStyle(Color.heTextTertiary)
                }

                ForEach(document.sections) { section in
                    VStack(alignment: .leading, spacing: HESpacing.sm) {
                        if let heading = section.heading {
                            Text(heading)
                                .font(.heHeadline)
                                .foregroundStyle(Color.heTextPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        ForEach(Array(section.paragraphs.enumerated()), id: \.offset) { _, paragraph in
                            Text(paragraph)
                                .font(.heBody)
                                .foregroundStyle(Color.heTextSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        if !section.bullets.isEmpty {
                            VStack(alignment: .leading, spacing: HESpacing.xs) {
                                ForEach(Array(section.bullets.enumerated()), id: \.offset) { _, bullet in
                                    HStack(alignment: .top, spacing: HESpacing.xs) {
                                        Text("•").foregroundStyle(Color.heTextTertiary)
                                        Text(bullet)
                                            .font(.heBody)
                                            .foregroundStyle(Color.heTextSecondary)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                Link("Contact \(LegalDocument.supportEmail)", destination: URL(string: "mailto:\(LegalDocument.supportEmail)")!)
                    .font(.heCallout)
                    .foregroundStyle(Color.hePrimary)
            }
            .padding(HESpacing.md)
        }
        .background(Color.heBackground)
        .navigationTitle(document.navTitle)
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Structured, self-contained legal copy. Rendered by `LegalDocumentView`.
struct LegalDocument {
    let title: String
    let navTitle: String
    let updated: String
    let sections: [Section]

    static let supportEmail = "support@heartelfie.app"

    struct Section: Identifiable {
        let id = UUID()
        var heading: String?
        var paragraphs: [String] = []
        var bullets: [String] = []
    }
}

#Preview("Privacy") {
    NavigationStack { LegalDocumentView(document: .privacyPolicy) }
}

#Preview("Terms") {
    NavigationStack { LegalDocumentView(document: .termsOfUse) }
}
