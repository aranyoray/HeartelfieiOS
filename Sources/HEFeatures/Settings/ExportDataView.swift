import SwiftUI
import HECore
import HEDesign

/// Full data portability: builds a CSV and a PDF of every reading and offers them
/// through the system share sheet. The PDF carries the non-diagnostic disclaimer
/// (added by the exporter). Building happens off the main actor; the UI shows a
/// calm loading state and the resulting counts.
struct ExportDataView: View {
    @Environment(AppEnvironment.self) private var env

    @State private var phase: Phase = .loading

    init() {}

    private enum Phase {
        case loading
        case ready(Export)
        case empty
        case failed
    }

    /// The built artifacts, ready to share.
    private struct Export {
        let count: Int
        let csvURL: URL
        let pdfURL: URL
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HESpacing.xl) {
                HESectionHeader(
                    title: "Export your data",
                    subtitle: "Take a full copy of your readings with you.",
                    systemImage: "square.and.arrow.up.fill"
                )

                content

                NonDiagnosticFooter()
            }
            .padding(HESpacing.md)
        }
        .background(Color.heBackground)
        .navigationTitle("Export data")
        .navigationBarTitleDisplayMode(.inline)
        .task { await build() }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .loading:
            HECard {
                LoadingStateView(message: "Preparing your export…")
            }

        case .empty:
            HECard {
                EmptyStateView(
                    systemImage: "tray",
                    title: "Nothing to export yet",
                    message: "Take a check or two and your readings will appear here, ready to export."
                )
            }

        case .failed:
            HECard {
                ErrorStateView(
                    message: "We couldn't prepare your export. Please try again.",
                    retry: { retry() }
                )
            }

        case .ready(let export):
            readyCard(export)
        }
    }

    private func readyCard(_ export: Export) -> some View {
        VStack(spacing: HESpacing.md) {
            HECard {
                VStack(alignment: .leading, spacing: HESpacing.sm) {
                    Label("\(export.count) \(export.count == 1 ? "reading" : "readings") ready", systemImage: "checkmark.circle.fill")
                        .font(.heHeadline)
                        .foregroundStyle(Color.heTextPrimary)
                    Text("Share a spreadsheet-friendly CSV or a formatted PDF. The PDF includes the wellness and screening disclaimer.")
                        .font(.heCallout)
                        .foregroundStyle(Color.heTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            ShareLink(item: export.csvURL) {
                shareLabel(title: "Share CSV", systemImage: "tablecells")
            }
            .accessibilityLabel("Share readings as C S V")

            ShareLink(item: export.pdfURL) {
                shareLabel(title: "Share PDF", systemImage: "doc.richtext")
            }
            .accessibilityLabel("Share readings as P D F")
        }
    }

    private func shareLabel(title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.heHeadline)
            .frame(maxWidth: .infinity, minHeight: 50)
            .foregroundStyle(.white)
            .background(Color.hePrimary, in: RoundedRectangle(cornerRadius: HERadius.md))
    }

    // MARK: - Build

    private func retry() {
        phase = .loading
        Task { await build() }
    }

    private func build() async {
        let readings = (try? await env.repository.allReadings()) ?? []
        guard !readings.isEmpty else {
            phase = .empty
            return
        }

        let profile = env.profile
        let exporter = env.exporter
        let stamp = Self.fileStamp()

        do {
            let csvURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("Heartelfie-readings-\(stamp).csv")
            let pdfURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("Heartelfie-readings-\(stamp).pdf")

            try exporter.writeCSV(readings, to: csvURL)
            try exporter.writePDF(readings, profile: profile, to: pdfURL)

            phase = .ready(Export(count: readings.count, csvURL: csvURL, pdfURL: pdfURL))
        } catch {
            phase = .failed
        }
    }

    private static func fileStamp() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        return formatter.string(from: Date())
    }
}

#Preview("Export data") {
    NavigationStack {
        ExportDataView()
            .environment(AppEnvironment.preview())
    }
}
