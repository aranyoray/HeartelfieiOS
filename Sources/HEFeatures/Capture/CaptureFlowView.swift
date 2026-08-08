import SwiftUI
import HECore
import HEDesign

/// The per-modality capture flow: live preview + real-time SQI coaching →
/// countdown → capture with progress → processing → result (or actionable
/// poor-signal coaching). Abortable throughout.
public struct CaptureFlowView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss

    public let modality: Modality
    @State private var vm: CaptureViewModel?
    @State private var countdown: Int?

    public init(modality: Modality) {
        self.modality = modality
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: HESpacing.lg) {
                header
                if let vm {
                    content(for: vm)
                } else {
                    LoadingStateView(message: "Preparing sensor…")
                        .frame(height: 280)
                }
            }
            .padding(HESpacing.md)
        }
        .background(Color.heBackground)
        .navigationTitle(modality.shortName)
        .navigationBarTitleDisplayMode(.inline)
        .sensoryFeedback(trigger: vm?.phase) { _, newPhase in
            switch newPhase {
            case .capturing: return .impact(weight: .medium)
            case .completed: return .success
            case .failed: return .error
            default: return nil
            }
        }
        .task {
            if vm == nil {
                let model = env.makeCaptureViewModel(for: modality)
                vm = model
                await model.begin()
            }
        }
        .onDisappear { Task { await vm?.abort() } }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: HESpacing.sm) {
            HStack {
                TierBadge(modality.tier)
                if modality.isExperimental {
                    Text("Experimental")
                        .font(.heCaption)
                        .padding(.horizontal, HESpacing.sm)
                        .padding(.vertical, 4)
                        .background(Color.heTextTertiary.opacity(0.15), in: Capsule())
                }
                Spacer()
            }
            Text(modality.summary)
                .font(.heCallout)
                .foregroundStyle(Color.heTextSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Phase content

    @ViewBuilder
    private func content(for vm: CaptureViewModel) -> some View {
        switch vm.phase {
        case .idle, .preparing, .coaching, .countdown, .capturing:
            liveCaptureSection(for: vm)
        case .processing:
            processingSection
        case .completed(let reading):
            CaptureResultSummary(reading: reading) { Task { await vm.abort(); dismiss() } }
        case .failed(let error):
            failureSection(for: vm, error: error)
        }
    }

    private func liveCaptureSection(for vm: CaptureViewModel) -> some View {
        VStack(spacing: HESpacing.lg) {
            ZStack {
                LiveWaveformView(samples: vm.liveWaveform, tint: .hePrimary, isLive: true)
                    .frame(height: 160)
                    .background(Color.heSurface, in: RoundedRectangle(cornerRadius: HERadius.lg))

                if vm.phase == .capturing {
                    CountdownRing(
                        progress: vm.captureProgress,
                        secondsRemaining: max(0, Int((captureWindow - vm.elapsedSeconds).rounded(.up)))
                    )
                    .frame(width: 96, height: 96)
                }
                if let countdown {
                    Text("\(countdown)")
                        .font(.system(size: 88, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.hePrimary)
                        .transition(.scale.combined(with: .opacity))
                }
            }

            HStack(spacing: HESpacing.lg) {
                PulseHeartView(bpm: vm.liveBPM)
                    .frame(width: 56, height: 56)
                if let bpm = vm.liveBPM {
                    VStack(alignment: .leading) {
                        Text("\(Int(bpm))")
                            .font(.heMetricNumeralCompact)
                            .foregroundStyle(Color.heTextPrimary)
                        Text("bpm (live estimate)")
                            .font(.heCaption)
                            .foregroundStyle(Color.heTextSecondary)
                    }
                } else {
                    Text("Reading your signal…")
                        .font(.heCallout)
                        .foregroundStyle(Color.heTextSecondary)
                }
                Spacer()
            }

            if let quality = vm.liveQuality {
                SQICoachBanner(quality: quality)
            }

            controls(for: vm)
        }
    }

    @ViewBuilder
    private func controls(for vm: CaptureViewModel) -> some View {
        if vm.phase == .capturing {
            HESecondaryButton("Cancel", systemImage: "xmark") {
                Task { await vm.abort(); dismiss() }
            }
        } else if countdown == nil {
            VStack(spacing: HESpacing.sm) {
                HEPrimaryButton("Start \(modality.tier == .measurement ? "Measurement" : "Screening")", systemImage: "record.circle") {
                    startCountdown(for: vm)
                }
                Text("Get a steady signal above, then hold still for about \(Int(captureWindow)) seconds.")
                    .font(.heCaption)
                    .foregroundStyle(Color.heTextTertiary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var processingSection: some View {
        VStack(spacing: HESpacing.md) {
            LoadingStateView(message: "Analyzing your reading…")
                .frame(height: 220)
            Text("Running the signal-quality check and feature extraction on-device.")
                .font(.heCaption)
                .foregroundStyle(Color.heTextTertiary)
                .multilineTextAlignment(.center)
        }
    }

    private func failureSection(for vm: CaptureViewModel, error: CaptureError) -> some View {
        VStack(spacing: HESpacing.md) {
            if case .poorSignalQuality(let quality) = error {
                SQICoachBanner(quality: quality)
                Text("We didn't compute any numbers from this signal — a poor-quality reading is never turned into a metric.")
                    .font(.heCaption)
                    .foregroundStyle(Color.heTextSecondary)
                    .multilineTextAlignment(.center)
            } else {
                ErrorStateView(message: error.userMessage) {
                    Task { await vm.retry() }
                }
            }
            HEPrimaryButton("Try Again", systemImage: "arrow.clockwise") {
                Task { await vm.retry() }
            }
        }
        .padding(.top, HESpacing.lg)
    }

    // MARK: - Helpers

    private var captureWindow: Double { ClinicalConfig.minimumCaptureSeconds(for: modality) + 2 }

    private func startCountdown(for vm: CaptureViewModel) {
        Task {
            for value in stride(from: 3, through: 1, by: -1) {
                withAnimation { countdown = value }
                try? await Task.sleep(for: .seconds(1))
            }
            withAnimation { countdown = nil }
            vm.startCapture()
        }
    }
}

/// Inline rich summary shown right after a successful capture, before the user
/// optionally drills into the full result detail.
struct CaptureResultSummary: View {
    let reading: CardioReading
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: HESpacing.md) {
            Label("Reading saved", systemImage: "checkmark.seal.fill")
                .font(.heHeadline)
                .foregroundStyle(Color.heRisk(.normal))

            HStack(spacing: HESpacing.sm) {
                TierBadge(reading.tier)
                ConfidenceMeter(reading.confidence)
            }

            ForEach(reading.metrics) { metric in
                MetricCardView(metric: metric)
            }

            HECard {
                Text(reading.interpretation)
                    .font(.heCallout)
                    .foregroundStyle(Color.heTextSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            NavigationLink(value: AppRoute.readingDetail(reading)) {
                Text("See full detail & export")
                    .font(.heHeadline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, HESpacing.sm)
            }
            .buttonStyle(SecondaryButtonStyle())

            HEPrimaryButton("Done", systemImage: "checkmark") { onDone() }

            NonDiagnosticFooter()
        }
    }
}

#Preview {
    NavigationStack {
        CaptureFlowView(modality: .fingerPPG)
            .environment(AppEnvironment.preview())
    }
}
