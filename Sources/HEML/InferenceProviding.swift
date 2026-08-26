import Foundation
import HECore
import HESignal

/// Additional inferred metrics for a reading, on top of whatever the on-device
/// DSP stage (`SignalProcessor`) already produced.
public struct InferenceResult: Sendable {
    /// Inferred metrics. Same-kind rows replace DSP metrics; new kinds are appended.
    public let metrics: [CardioMetric]
    /// Provenance for these metrics (on-device CoreML / on-device DSP).
    public let provenance: Provenance
    /// Optional confidence for these metrics.
    public let confidence: Confidence?
    /// Optional non-diagnostic interpretation note.
    public let interpretation: String?

    public init(metrics: [CardioMetric],
                provenance: Provenance,
                confidence: Confidence? = nil,
                interpretation: String? = nil) {
        self.metrics = metrics
        self.provenance = provenance
        self.confidence = confidence
        self.interpretation = interpretation
    }

    /// An empty on-device-DSP result — the DSP stage already did the work and no
    /// further inference applies (used for most phone modalities).
    public static let dspOnly = InferenceResult(metrics: [], provenance: .onDeviceDSP)
}

/// Produces additional inferred metrics for a modality from per-channel samples.
public protocol InferenceProviding: Sendable {
    func infer(modality: Modality,
               channels: [SignalChannel: [Double]],
               sampleRate: Double,
               profile: HealthProfile?,
               skinTone: MonkSkinTone?) async -> InferenceResult
}

/// Routes each phone modality to the right on-device inference. Finger PPG may
/// add an optional CoreML rhythm screen; facial rPPG uses DSP only.
public final class InferenceCoordinator: InferenceProviding {

    private let onDevice: OnDeviceModels

    public init(onDevice: OnDeviceModels = OnDeviceModels()) {
        self.onDevice = onDevice
    }

    public func infer(modality: Modality,
                      channels: [SignalChannel: [Double]],
                      sampleRate: Double,
                      profile: HealthProfile?,
                      skinTone: MonkSkinTone?) async -> InferenceResult {
        switch modality {
        case .fingerPPG:
            return inferFingerPPGRhythmScreen(channels: channels, sampleRate: sampleRate, profile: profile)
        case .facialRPPG:
            return .dspOnly
        }
    }

    private func inferFingerPPGRhythmScreen(channels: [SignalChannel: [Double]],
                                            sampleRate: Double,
                                            profile: HealthProfile?) -> InferenceResult {
        let primary = SignalProcessor.primaryChannel(for: .fingerPPG)
        guard let samples = channels[primary] ?? channels.values.first, samples.count > 8 else {
            return .dspOnly
        }
        // No bundled model → keep the DSP metrics, provenance, and confidence.
        // Replacing them with the heuristic fabricated results (including a
        // hard 0% irregularity on <3 detected peaks) and mislabeled provenance.
        guard let screen = onDevice.screenRhythm(samples: samples, sampleRate: sampleRate) else {
            return .dspOnly
        }
        let metric = CardioMetric(
            kind: .rhythmIrregularity,
            value: screen.irregularityPercent.rounded(),
            note: "On-device rhythm screen — approximate.",
            profile: profile
        )
        return InferenceResult(
            metrics: [metric],
            provenance: .onDeviceCoreML,
            confidence: screen.confidence,
            interpretation: nil
        )
    }
}
