import SwiftUI
import UIKit
import HECore
import HEDesign

/// Full data portability: builds a CSV or a PDF of every reading on demand and
/// offers it through the system share sheet. The PDF carries the non-diagnostic
/// disclaimer (added by the exporter). Nothing is written to disk until the user
/// actually taps a share button, and the generated file is deleted again as soon
/// as the share sheet is dismissed.
struct ExportDataView: View {
    @Environment(AppEnvironment.self) private var env

    @State private var phase: Phase = .loading
    @State private var isBuilding = false
    @State private var shareItem: ShareItem?
    /// Files this screen has written, cleaned up after sharing / on leaving.
    @State private var generatedURLs: [URL] = []

    init() {}

    private enum Phase {
        case loading
        case ready(count: Int)
        case empty
        case failed
    }

    private enum ExportKind {
        case csv, pdf

        var fileExtension: String {
            switch self {
            case .csv: return "csv"
            case .pdf: return "pdf"
            }
        }
    }

    /// A built artifact, ready to hand to the share sheet.
    private struct ShareItem: Identifiable {
        let id = UUID()
        let url: URL
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
        .task { await load() }
        .sheet(item: $shareItem, onDismiss: { cleanupGeneratedFiles() }) { item in
            ActivityShareSheet(url: item.url) {
                shareItem = nil
            }
            .ignoresSafeArea()
        }
        .onDisappear { cleanupGeneratedFiles() }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .loading:
            HECard {
                LoadingStateView(message: "Checking your readings…")
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

        case .ready(let count):
            readyCard(count: count)
        }
    }

    private func readyCard(count: Int) -> some View {
        VStack(spacing: HESpacing.md) {
            HECard {
                VStack(alignment: .leading, spacing: HESpacing.sm) {
                    Label("\(count) \(count == 1 ? "reading" : "readings") ready", systemImage: "checkmark.circle.fill")
                        .font(.heHeadline)
                        .foregroundStyle(Color.heTextPrimary)
                    Text("Share a spreadsheet-friendly CSV or a formatted PDF. The PDF includes the wellness and screening disclaimer. Files are built when you tap share and removed afterwards.")
                        .font(.heCallout)
                        .foregroundStyle(Color.heTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button { share(.csv) } label: {
                shareLabel(title: "Share CSV", systemImage: "tablecells")
            }
            .disabled(isBuilding)
            .accessibilityLabel("Share readings as C S V")

            Button { share(.pdf) } label: {
                shareLabel(title: "Share PDF", systemImage: "doc.richtext")
            }
            .disabled(isBuilding)
            .accessibilityLabel("Share readings as P D F")
        }
    }

    private func shareLabel(title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.heHeadline)
            .frame(maxWidth: .infinity, minHeight: 50)
            .foregroundStyle(.white)
            .background(Color.hePrimary, in: RoundedRectangle(cornerRadius: HERadius.md))
            .opacity(isBuilding ? 0.6 : 1)
    }

    // MARK: - Load / build

    private func retry() {
        phase = .loading
        Task { await load() }
    }

    /// Only counts the readings up front — files aren't written until the user
    /// actually asks to share one.
    private func load() async {
        do {
            let readings = try await env.repository.allReadings()
            phase = readings.isEmpty ? .empty : .ready(count: readings.count)
        } catch {
            phase = .failed
        }
    }

    /// Builds the requested artifact into the temporary directory and hands it
    /// to the share sheet.
    private func share(_ kind: ExportKind) {
        guard !isBuilding else { return }
        isBuilding = true
        Task {
            defer { isBuilding = false }
            do {
                let readings = try await env.repository.allReadings()
                guard !readings.isEmpty else {
                    phase = .empty
                    return
                }

                let url = FileManager.default.temporaryDirectory
                    .appendingPathComponent("DailyDil-readings-\(Self.fileStamp()).\(kind.fileExtension)")
                // Rendering a full-history PDF/CSV is CPU-bound; keep it off the
                // main actor so the spinner can actually animate.
                let exporter = env.exporter
                switch kind {
                case .csv:
                    try await Task.detached { try exporter.writeCSV(readings, to: url) }.value
                case .pdf:
                    let profile = env.profile
                    try await Task.detached { try exporter.writePDF(readings, profile: profile, to: url) }.value
                }

                generatedURLs.append(url)
                phase = .ready(count: readings.count)
                shareItem = ShareItem(url: url)
            } catch {
                phase = .failed
            }
        }
    }

    /// Removes every file this screen generated. Called once the share sheet is
    /// dismissed and again on leaving the screen, so exports never linger in tmp.
    private func cleanupGeneratedFiles() {
        for url in generatedURLs {
            try? FileManager.default.removeItem(at: url)
        }
        generatedURLs = []
    }

    private static func fileStamp() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        return formatter.string(from: Date())
    }
}

/// Wraps `UIActivityViewController` so the generated file can be cleaned up via
/// its completion handler as soon as the user finishes (or cancels) sharing.
private struct ActivityShareSheet: UIViewControllerRepresentable {
    let url: URL
    let onComplete: () -> Void

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        let onComplete = onComplete
        controller.completionWithItemsHandler = { _, _, _, _ in
            onComplete()
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview("Export data") {
    NavigationStack {
        ExportDataView()
            .environment(AppEnvironment.preview())
    }
}
