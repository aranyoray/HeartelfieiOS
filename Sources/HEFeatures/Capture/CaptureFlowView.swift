import SwiftUI
import UIKit
import HECore
import HEDesign

/// The per-modality capture flow.
///
/// Finger PPG uses an explicit, user-paced flow: the camera only turns on after
/// the user asks, live coaching + waveform + settling heart-rate estimate are
/// shown as a card stack, and saving a reading is a deliberate start/finish
/// action. Other modalities keep the countdown-driven window flow.
/// Abortable throughout.
public struct CaptureFlowView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL

    public let modality: Modality
    @State private var vm: CaptureViewModel?
    @State private var countdown: Int?
    @State private var countdownTask: Task<Void, Never>?

    public init(modality: Modality) {
        self.modality = modality
    }

    private var isFingerFlow: Bool { modality == .fingerPPG }

    /// Re-arms the heartbeat-haptic task whenever the live phase flips.
    private var heartbeatTaskKey: Bool {
        vm?.phase == .coaching || vm?.phase == .capturing
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
            .padding(.horizontal, HESpacing.screen)
            .padding(.vertical, HESpacing.md)
        }
        .background(Color.heBackground)
        .navigationTitle(modality.shortName)
        .navigationBarTitleDisplayMode(.inline)
        // A capture is a focused task; the tab bar only invites mid-capture
        // tab switches and covers the bottom card.
        .toolbar(.hidden, for: .tabBar)
        .sensoryFeedback(trigger: vm?.phase) { _, newPhase in
            switch newPhase {
            case .preparing: return .impact(weight: .light)
            case .capturing: return .impact(weight: .medium)
            case .completed: return .success
            case .failed: return .error
            default: return nil
            }
        }
        .task(id: heartbeatTaskKey) {
            // A soft haptic tick per detected beat while live — the reading
            // becomes something you can feel, not just watch.
            guard let vm, vm.phase == .coaching || vm.phase == .capturing else { return }
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.prepare()
            while !Task.isCancelled, vm.phase == .coaching || vm.phase == .capturing {
                if let bpm = vm.liveBPM, (30...220).contains(bpm) {
                    generator.impactOccurred(intensity: 0.55)
                    try? await Task.sleep(for: .seconds(60.0 / bpm))
                } else {
                    try? await Task.sleep(for: .milliseconds(300))
                }
            }
        }
        .task {
            if vm == nil {
                let model = env.makeCaptureViewModel(for: modality)
                vm = model
                // The finger flow waits for an explicit "Start camera" tap; the
                // camera never runs before the user asks for it.
                if !isFingerFlow {
                    await model.begin()
                }
            }
        }
        .onDisappear {
            countdownTask?.cancel()
            countdownTask = nil
            countdown = nil
            Task {
                // Pushing the result detail covers this view; don't tear down a
                // finished reading or the user comes back to an empty capture.
                if case .completed = vm?.phase { return }
                await vm?.abort()
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .background:
                // Backgrounding mid-flow must tear the camera down (torch off,
                // no half-captures); a finished or failed reading is left alone.
                // `.inactive` is deliberately NOT handled: the camera-permission
                // alert, Control Center, and call banners all pass through it.
                switch vm?.phase {
                case .preparing, .coaching, .capturing, .processing:
                    countdownTask?.cancel()
                    countdownTask = nil
                    countdown = nil
                    Task { await vm?.abort() }
                default:
                    break
                }
            case .active:
                // The legacy (face) flow auto-begins from .task only once; after
                // a background abort it would otherwise dead-end on "Starting
                // camera…" with no way to restart.
                if let vm, vm.phase == .idle, !isFingerFlow {
                    Task { await vm.begin() }
                }
            default:
                break
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: HESpacing.sm) {
            HStack {
                TierBadge(modality.tier)
                Spacer()
                if let vm, vm.phase == .coaching || vm.phase == .capturing {
                    livePill
                }
            }
            Text(modality.summary)
                .font(.heCallout)
                .foregroundStyle(Color.heTextSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var livePill: some View {
        HStack(spacing: HESpacing.xs) {
            Circle()
                .fill(Color.heAccent)
                .frame(width: 7, height: 7)
            Text("Live")
                .font(.heCaption)
                .foregroundStyle(Color.heTextSecondary)
        }
        .padding(.horizontal, HESpacing.sm)
        .padding(.vertical, HESpacing.xs)
        .background(Color.heSurface, in: Capsule())
    }

    // MARK: - Phase content

    @ViewBuilder
    private func content(for vm: CaptureViewModel) -> some View {
        if isFingerFlow {
            fingerContent(for: vm)
        } else {
            legacyContent(for: vm)
        }
    }

    // MARK: - Finger PPG flow

    @ViewBuilder
    private func fingerContent(for vm: CaptureViewModel) -> some View {
        switch vm.phase {
        case .idle:
            readyCard(for: vm)
        case .preparing:
            startingCard
        case .coaching, .capturing:
            measuringStack(for: vm)
        case .processing:
            processingSection
        case .completed(let reading):
            CaptureResultSummary(reading: reading) { Task { await vm.abort(); dismiss() } }
        case .failed(let error):
            failureSection(for: vm, error: error)
        }
    }

    /// Camera off; nothing runs until the user asks.
    private func readyCard(for vm: CaptureViewModel) -> some View {
        HECard {
            VStack(spacing: HESpacing.md) {
                iconBadge("camera.aperture", size: 72)
                Text("Ready to take a reading")
                    .font(.heHeadline)
                    .foregroundStyle(Color.heTextPrimary)
                Text("\(HeartelfieConfig.appName) turns on the camera only after you start. Rest a fingertip over the rear camera and hold still while the estimate settles.")
                    .font(.heCallout)
                    .foregroundStyle(Color.heTextSecondary)
                    .multilineTextAlignment(.center)
                HEPrimaryButton("Start camera", systemImage: "camera.fill") {
                    Task { await vm.begin() }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, HESpacing.lg)
        }
    }

    private var startingCard: some View {
        HECard {
            VStack(spacing: HESpacing.md) {
                ProgressView()
                    .controlSize(.large)
                    .tint(Color.hePrimary)
                Text("Getting the camera ready…")
                    .font(.heCallout)
                    .foregroundStyle(Color.heTextSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, HESpacing.xl)
        }
    }

    /// Live measuring card stack: guidance → live pulse → estimate → save.
    private func measuringStack(for vm: CaptureViewModel) -> some View {
        VStack(spacing: HESpacing.md) {
            guidanceCard(for: vm)
            livePulseCard(for: vm)
            estimateCard(for: vm)
            saveCard(for: vm)
        }
    }

    private var hasSignal: Bool {
        guard let vm else { return false }
        return vm.liveWaveform.count > 30
    }

    private func guidanceCard(for vm: CaptureViewModel) -> some View {
        let hasContact = vm.liveWaveform.count > 30
        // Don't say "looking good" while the SQI banner below is still coaching
        // the user to improve the signal — the two must never contradict.
        let hasEstimate = vm.liveBPM != nil && (vm.liveQuality?.isAcceptable ?? false)
        let headline: String
        let support: String
        let glyph: String
        if !hasContact {
            headline = "Rest a fingertip over the rear camera"
            support = "Cover the camera and torch gently, then hold still."
            glyph = "hand.tap.fill"
        } else if !hasEstimate {
            headline = "Hold still, settling…"
            support = "Stay relaxed for a few seconds while the estimate steadies."
            glyph = "hand.tap.fill"
        } else {
            headline = "Looking good — keep holding"
            support = "Stay relaxed for a few seconds while the estimate steadies."
            glyph = "checkmark.circle.fill"
        }
        return HECard {
            VStack(alignment: .leading, spacing: HESpacing.md) {
                HStack(spacing: HESpacing.md) {
                    iconBadge(glyph, size: 40)
                    VStack(alignment: .leading, spacing: HESpacing.xxs) {
                        Text(headline)
                            .font(.heHeadline)
                            .foregroundStyle(Color.heTextPrimary)
                        Text(support)
                            .font(.heCaption)
                            .foregroundStyle(Color.heTextSecondary)
                    }
                    Spacer(minLength: 0)
                }
                if let quality = vm.liveQuality {
                    SQICoachBanner(quality: quality)
                }
            }
        }
    }

    private func livePulseCard(for vm: CaptureViewModel) -> some View {
        HECard {
            VStack(alignment: .leading, spacing: HESpacing.sm) {
                HESectionHeader(title: "Live pulse")
                LiveWaveformView(samples: vm.liveWaveform, tint: .hePrimary, isLive: true)
                    .frame(height: 128)
            }
        }
    }

    private func estimateCard(for vm: CaptureViewModel) -> some View {
        HECard {
            VStack(alignment: .leading, spacing: HESpacing.sm) {
                HESectionHeader(title: "Heart-rate estimate")
                HStack(spacing: HESpacing.md) {
                    PulseHeartView(bpm: vm.liveBPM)
                        .frame(width: 44, height: 44)
                    if let bpm = vm.liveBPM {
                        HStack(alignment: .firstTextBaseline, spacing: HESpacing.xs) {
                            Text("\(Int(bpm))")
                                .font(.heMetricNumeralCompact)
                                .foregroundStyle(Color.heTextPrimary)
                                .contentTransition(.numericText())
                                .animation(.default, value: Int(bpm))
                            Text("bpm")
                                .font(.heUnit)
                                .foregroundStyle(Color.heTextSecondary)
                        }
                    } else if hasSignal {
                        HStack(spacing: HESpacing.sm) {
                            ProgressView()
                                .tint(Color.hePrimary)
                            Text("Settling…")
                                .font(.heCallout)
                                .foregroundStyle(Color.heTextSecondary)
                        }
                    } else {
                        Text("Waiting for signal…")
                            .font(.heCallout)
                            .foregroundStyle(Color.heTextSecondary)
                    }
                    Spacer(minLength: 0)
                }
                Text("Estimated from the camera • wellness screening only — not a medical measurement.")
                    .font(.heCaption)
                    .foregroundStyle(Color.heTextTertiary)
            }
        }
    }

    @ViewBuilder
    private func saveCard(for vm: CaptureViewModel) -> some View {
        HECard {
            VStack(alignment: .leading, spacing: HESpacing.md) {
                HESectionHeader(title: "Save this reading")
                if vm.phase == .capturing {
                    HStack {
                        Label("Saving · \(clock(vm.elapsedSeconds))", systemImage: "record.circle")
                            .font(.heHeadline)
                            .foregroundStyle(Color.hePrimary)
                            .contentTransition(.numericText())
                        Spacer()
                    }
                    ProgressView(value: min(max(vm.captureProgress, 0), 1))
                        .progressViewStyle(.linear)
                        .tint(Color.hePrimary)
                    if vm.captureWasInterrupted {
                        Text("The signal was interrupted, so this save restarted from the steady part.")
                            .font(.heCaption)
                            .foregroundStyle(Color.heTextSecondary)
                    }
                    if vm.secondsUntilFinishAllowed > 0 {
                        Text("Keep holding — about \(Int(vm.secondsUntilFinishAllowed.rounded(.up)))s more for a valid reading.")
                            .font(.heCaption)
                            .foregroundStyle(Color.heTextTertiary)
                    }
                    HEPrimaryButton("Finish", systemImage: "stop.circle.fill") {
                        Task { await vm.finishEarly() }
                    }
                    .disabled(vm.secondsUntilFinishAllowed > 0)
                    HESecondaryButton("Cancel", systemImage: "xmark") {
                        Task { await vm.abort(); dismiss() }
                    }
                } else {
                    HEPrimaryButton("Start saving", systemImage: "record.circle") {
                        vm.startCapture()
                    }
                    .disabled(vm.liveBPM == nil)
                    if vm.liveBPM == nil {
                        Text("Wait for a heart-rate estimate first.")
                            .font(.heCaption)
                            .foregroundStyle(Color.heTextTertiary)
                    } else {
                        Text("Saves about \(Int(captureWindow)) seconds of signal, then checks its quality on-device.")
                            .font(.heCaption)
                            .foregroundStyle(Color.heTextTertiary)
                    }
                }
            }
        }
    }

    private func iconBadge(_ systemImage: String, size: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(Color.hePrimary.opacity(0.12))
            Image(systemName: systemImage)
                .font(.system(size: size * 0.42, weight: .medium))
                .foregroundStyle(Color.hePrimary)
        }
        .frame(width: size, height: size)
    }

    private func clock(_ seconds: Double) -> String {
        let total = max(0, Int(seconds))
        return String(format: "%02d:%02d", total / 60, total % 60)
    }

    // MARK: - Legacy flow (non-finger modalities)

    @ViewBuilder
    private func legacyContent(for vm: CaptureViewModel) -> some View {
        switch vm.phase {
        case .idle, .preparing, .coaching, .capturing:
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

            if vm.phase == .capturing, vm.captureWasInterrupted {
                Text("The signal was interrupted, so this capture restarted from the steady part.")
                    .font(.heCaption)
                    .foregroundStyle(Color.heTextSecondary)
                    .multilineTextAlignment(.center)
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
            // The countdown no-ops unless the stream is live, so only offer the
            // start button once coaching has begun; before that, say why.
            if vm.phase == .coaching {
                VStack(spacing: HESpacing.sm) {
                    HEPrimaryButton("Start Screening", systemImage: "record.circle") {
                        startCountdown(for: vm)
                    }
                    Text("Get a steady signal above, then hold still for about \(Int(captureWindow)) seconds.")
                        .font(.heCaption)
                        .foregroundStyle(Color.heTextTertiary)
                        .multilineTextAlignment(.center)
                }
            } else {
                Text("Starting camera…")
                    .font(.heCaption)
                    .foregroundStyle(Color.heTextTertiary)
            }
        }
    }

    // MARK: - Shared sections

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
            if case .sensorUnavailable = error {
                // Camera-permission denial lands here; offer the direct fix.
                HESecondaryButton("Open Settings", systemImage: "gear") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        openURL(url)
                    }
                }
            }
        }
        .padding(.top, HESpacing.lg)
    }

    // MARK: - Helpers

    private var captureWindow: Double { ClinicalConfig.minimumCaptureSeconds(for: modality) + 2 }

    private func startCountdown(for vm: CaptureViewModel) {
        countdownTask?.cancel()
        countdownTask = Task {
            for value in stride(from: 3, through: 1, by: -1) {
                guard !Task.isCancelled else { return }
                withAnimation { countdown = value }
                try? await Task.sleep(for: .seconds(1))
            }
            guard !Task.isCancelled else { return }
            withAnimation { countdown = nil }
            guard vm.phase == .coaching else { return }
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
            HEHeroCard {
                VStack(alignment: .leading, spacing: HESpacing.sm) {
                    Label("Reading saved", systemImage: "checkmark.seal.fill")
                        .font(.heHeadline)
                        .foregroundStyle(.white)

                    if let hr = reading.metrics.first(where: { $0.kind == .heartRate }) {
                        HStack(alignment: .firstTextBaseline, spacing: HESpacing.xs) {
                            Text(verbatim: "\(Int(hr.value))")
                                .font(.heMetricNumeralCompact)
                                .foregroundStyle(.white)
                                .monospacedDigit()
                            Text(hr.kind.unit)
                                .font(.heUnit)
                                .foregroundStyle(.white.opacity(0.85))
                        }
                    }

                    HStack(spacing: HESpacing.sm) {
                        TierBadge(reading.tier)
                        ConfidenceMeter(reading.confidence)
                    }
                    .padding(.horizontal, HESpacing.xs)
                    .padding(.vertical, HESpacing.xxs)
                    .background(RoundedRectangle(cornerRadius: HERadius.md, style: .continuous).fill(.white.opacity(0.92)))
                    // The strip is a fixed white surface; dynamic dark-mode text
                    // colors would render near-white-on-white.
                    .environment(\.colorScheme, .light)
                }
            }

            ForEach(reading.metrics.filter { $0.kind != .heartRate }) { metric in
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
