import SwiftUI
import HECore
import HEDesign
import HEPersistence

/// The full result screen for a single `CardioReading`.
///
/// Surfaces everything that makes a reading self-describing and honest: the
/// rendered waveform, the trust tier, the full metric set, confidence, signal
/// quality, and model provenance (with any license attribution always visible).
/// Adds the non-diagnostic interpretation, what-it-means / what-it-doesn't-mean
/// copy, PDF/CSV export, a wellness-context card, and - when confidence
/// is low — a calm recheck prompt with a partner-clinic pathway.
struct ResultDetailView: View {
    @Environment(AppEnvironment.self) private var env

    private let reading: CardioReading

    @State private var exportDocs: ExportDocuments?
    @State private var isPreparingExport = false
    @State private var didAppear = false
    @State private var exportReadyTick = 0

    init(reading: CardioReading) {
        self.reading = reading
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HESpacing.xl) {
                headerSection
                if reading.confidence.isLow {
                    recheckSection
                }
                waveformSection
                qualitySection
                metricsSection
                interpretationSection
                if CareGuidance.shouldSurfaceCare(tier: reading.tier, risk: reading.overallRisk) {
                    CareAccessCard(
                        tier: reading.tier,
                        risk: reading.overallRisk,
                        lowConfidence: reading.confidence.isLow
                    )
                }
                provenanceSection
                actionsSection
                NonDiagnosticFooter()
                EmergencyNotice()
            }
            .padding(HESpacing.md)
        }
        .background(Color.heBackground)
        .navigationTitle(reading.modality.shortName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { exportToolbarItem }
        .sheet(item: $exportDocs) { docs in
            ExportShareSheet(documents: docs)
        }
        // A gentle completion cue the first time a saved reading is opened.
        .sensoryFeedback(reading.confidence.isLow ? .warning : .success, trigger: didAppear)
        .sensoryFeedback(.success, trigger: exportReadyTick)
        .onAppear {
            guard !didAppear else { return }
            didAppear = true
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: HESpacing.sm) {
            HStack(spacing: HESpacing.sm) {
                Image(systemName: reading.modality.systemImage)
                    .font(.heTitle)
                    .foregroundStyle(Color.hePrimary)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: HESpacing.xxs) {
                    Text(reading.modality.displayName)
                        .font(.heTitle)
                        .foregroundStyle(Color.heTextPrimary)
                    Text(reading.timestamp, format: .dateTime.weekday(.wide).month(.wide).day().hour().minute())
                        .font(.heCaption)
                        .foregroundStyle(Color.heTextSecondary)
                }
                Spacer(minLength: 0)
            }
            .accessibilityElement(children: .combine)

            HStack(spacing: HESpacing.sm) {
                TierBadge(reading.tier)
                RiskBadge(reading.overallRisk)
            }
        }
    }

    // MARK: - Low-confidence recheck

    private var recheckSection: some View {
        VStack(alignment: .leading, spacing: HESpacing.md) {
            HStack(alignment: .top, spacing: HESpacing.md) {
                Image(systemName: "arrow.clockwise.circle.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(Color.heConfidence(.low))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: HESpacing.xs) {
                    Text("This reading was low confidence")
                        .font(.heHeadline)
                        .foregroundStyle(Color.heTextPrimary)
                    Text("The signal quality made this result uncertain. It's best read as a prompt to re-check rather than a result to act on. Try again when you're relaxed and still.")
                        .font(.heCallout)
                        .foregroundStyle(Color.heTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            NavigationLink(value: AppRoute.capture(reading.modality)) {
                Label("Re-check now", systemImage: "arrow.clockwise")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryButtonStyle())
            .accessibilityHint("Starts a new \(reading.modality.displayName) check.")
        }
        .padding(HESpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: HERadius.lg, style: .continuous)
                .fill(Color.heConfidence(.low).opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: HERadius.lg, style: .continuous)
                .strokeBorder(Color.heConfidence(.low).opacity(0.30), lineWidth: 1)
        )
    }

    // MARK: - Waveform

    private var waveformSection: some View {
        VStack(alignment: .leading, spacing: HESpacing.sm) {
            HESectionHeader(title: "Waveform", systemImage: "waveform.path.ecg")
            HECard {
                if reading.waveformPreview.count >= 2 {
                    LiveWaveformView(samples: reading.waveformPreview, isLive: false)
                        .frame(height: 120)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("Recorded waveform for this \(reading.modality.displayName) reading.")
                } else {
                    Text("No waveform was saved for this reading.")
                        .font(.heCallout)
                        .foregroundStyle(Color.heTextSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    // MARK: - Signal quality + confidence

    private var qualitySection: some View {
        VStack(alignment: .leading, spacing: HESpacing.md) {
            HESectionHeader(title: "Signal & confidence", systemImage: "gauge.with.dots.needle.bottom.50percent")

            SQICoachBanner(quality: reading.signalQuality)

            HECard {
                VStack(alignment: .leading, spacing: HESpacing.md) {
                    ConfidenceMeter(reading.confidence)

                    HStack(spacing: HESpacing.sm) {
                        Image(systemName: "waveform.badge.magnifyingglass")
                            .foregroundStyle(Color.hePrimary)
                            .accessibilityHidden(true)
                        Text("Signal quality")
                            .font(.heCallout)
                            .foregroundStyle(Color.heTextSecondary)
                        Spacer(minLength: 0)
                        Text("\(reading.signalQuality.band.displayName) (\(sqiPercent))")
                            .font(.heCallout.weight(.semibold))
                            .foregroundStyle(Color.heSQI(reading.signalQuality.band))
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Signal quality \(reading.signalQuality.band.displayName), \(sqiPercent).")
                }
            }
        }
    }

    private var sqiPercent: String {
        "\(Int((reading.signalQuality.sqi * 100).rounded()))%"
    }

    // MARK: - Metrics

    private var metricsSection: some View {
        VStack(alignment: .leading, spacing: HESpacing.md) {
            HESectionHeader(
                title: "Metrics",
                subtitle: reading.tier.disclaimer,
                systemImage: "list.bullet.rectangle"
            )

            if reading.metrics.isEmpty {
                HECard {
                    Text("No metrics were produced for this reading.")
                        .font(.heCallout)
                        .foregroundStyle(Color.heTextSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                VStack(spacing: HESpacing.md) {
                    ForEach(reading.metrics) { metric in
                        MetricCardView(metric: metric)
                    }
                }
            }
        }
    }

    // MARK: - Interpretation + disclaimers

    private var interpretationSection: some View {
        VStack(alignment: .leading, spacing: HESpacing.md) {
            HESectionHeader(title: "What this means", systemImage: "text.book.closed")

            HECard {
                VStack(alignment: .leading, spacing: HESpacing.md) {
                    Text(reading.interpretation)
                        .font(.heBody)
                        .foregroundStyle(Color.heTextPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    Divider().background(Color.heSeparator)

                    interpretationRow(
                        icon: "checkmark.circle",
                        title: "What it means",
                        body: Disclaimers.whatItMeans(for: reading.modality)
                    )
                    interpretationRow(
                        icon: "xmark.circle",
                        title: "What it doesn't mean",
                        body: Disclaimers.whatItDoesNotMean(for: reading.modality)
                    )
                }
            }
        }
    }

    private func interpretationRow(icon: String, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: HESpacing.sm) {
            Image(systemName: icon)
                .font(.heHeadline)
                .foregroundStyle(Color.hePrimary)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: HESpacing.xxs) {
                Text(title)
                    .font(.heCallout.weight(.semibold))
                    .foregroundStyle(Color.heTextPrimary)
                Text(body)
                    .font(.heCallout)
                    .foregroundStyle(Color.heTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(body)")
    }

    // MARK: - Provenance

    private var provenanceSection: some View {
        VStack(alignment: .leading, spacing: HESpacing.md) {
            HESectionHeader(
                title: "How this was produced",
                subtitle: "Model provenance for transparency.",
                systemImage: "shippingbox"
            )

            HECard {
                VStack(alignment: .leading, spacing: HESpacing.sm) {
                    provenanceRow(
                        icon: reading.provenance.engine.systemImage,
                        label: "Engine",
                        value: reading.provenance.engine.displayName
                    )
                    provenanceRow(
                        icon: "number",
                        label: "Model",
                        value: reading.provenance.shortLabel
                    )
                    if let tone = reading.monkSkinTone {
                        provenanceRow(
                            icon: "circle.lefthalf.filled",
                            label: "Skin tone used",
                            value: "Monk \(tone.value)"
                        )
                    }

                    // Attribution must always be visible when present (license obligation).
                    if let attribution = reading.provenance.attribution, !attribution.isEmpty {
                        Divider().background(Color.heSeparator)
                        VStack(alignment: .leading, spacing: HESpacing.xxs) {
                            Label("Attribution", systemImage: "quote.bubble")
                                .font(.heCaption.weight(.semibold))
                                .foregroundStyle(Color.heTextSecondary)
                            Text(attribution)
                                .font(.heCaption)
                                .foregroundStyle(Color.heTextSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Attribution. \(attribution)")
                    }
                }
            }
        }
    }

    private func provenanceRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: HESpacing.sm) {
            Image(systemName: icon)
                .foregroundStyle(Color.hePrimary)
                .frame(width: 24)
                .accessibilityHidden(true)
            Text(label)
                .font(.heCallout)
                .foregroundStyle(Color.heTextSecondary)
            Spacer(minLength: HESpacing.sm)
            Text(value)
                .font(.heCallout.weight(.medium))
                .foregroundStyle(Color.heTextPrimary)
                .multilineTextAlignment(.trailing)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }

    // MARK: - Actions (share and retake)

    private var actionsSection: some View {
        VStack(spacing: HESpacing.md) {
            HEPrimaryButton("Export PDF", systemImage: "doc.richtext") {
                Task { await prepareExport(.pdf) }
            }
            .accessibilityHint("Prepares a PDF of this reading to share outside Heartelfie if you choose.")

            HESecondaryButton("Export CSV", systemImage: "tablecells", isLoading: isPreparingExport) {
                Task { await prepareExport(.csv) }
            }
            .accessibilityHint("Prepares a CSV of this reading to share outside Heartelfie if you choose.")
        }
    }

    // MARK: - Export toolbar

    private var exportToolbarItem: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button {
                    Task { await prepareExport(.pdf) }
                } label: {
                    Label("Share PDF", systemImage: "doc.richtext")
                }
                Button {
                    Task { await prepareExport(.csv) }
                } label: {
                    Label("Share CSV", systemImage: "tablecells")
                }
            } label: {
                if isPreparingExport {
                    ProgressView()
                } else {
                    Image(systemName: "square.and.arrow.up")
                }
            }
            .disabled(isPreparingExport)
            .accessibilityLabel("Share this reading")
        }
    }

    // MARK: - Export building

    private func prepareExport(_ format: ExportFormat) async {
        isPreparingExport = true
        defer { isPreparingExport = false }
        let exporter = env.exporter
        let profile = env.profile
        let single = reading
        let stamp = Self.fileStamp(for: reading.timestamp)

        let url: URL? = await Task.detached(priority: .userInitiated) {
            let dir = FileManager.default.temporaryDirectory
            switch format {
            case .csv:
                let target = dir.appendingPathComponent("Heartelfie-Reading-\(stamp).csv")
                try? exporter.writeCSV([single], to: target)
                return FileManager.default.fileExists(atPath: target.path) ? target : nil
            case .pdf:
                let target = dir.appendingPathComponent("Heartelfie-Reading-\(stamp).pdf")
                try? exporter.writePDF([single], profile: profile, to: target)
                return FileManager.default.fileExists(atPath: target.path) ? target : nil
            }
        }.value

        if let url {
            exportDocs = ExportDocuments(url: url, format: format)
            exportReadyTick += 1
        }
    }

    private static func fileStamp(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: date)
    }
}

#Preview("Result — finger PPG") {
    NavigationStack {
        ResultDetailView(reading: SampleData.fingerPPGReading())
            .environment(AppEnvironment.preview())
    }
}

#Preview("Result — low confidence") {
    NavigationStack {
        ResultDetailView(reading: SampleData.lowConfidenceReading())
            .environment(AppEnvironment.preview())
    }
}
