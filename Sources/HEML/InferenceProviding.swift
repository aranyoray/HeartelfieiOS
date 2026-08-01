import Foundation
import HECore
import HESignal

/// Additional inferred metrics for a reading, on top of whatever the on-device
/// DSP stage (`SignalProcessor`) already produced. The `provenance` always
/// reflects the engine that produced *these* metrics, and for cloud results it
/// carries the model name + version + attribution that must be surfaced.
public struct InferenceResult: Sendable {
    /// ADDITIONAL metrics — e.g. device clinical metrics. Merged on top of DSP.
    public let metrics: [CardioMetric]
    /// Provenance for these metrics (cloud / on-device CoreML / on-device DSP).
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
    /// Produce additional inferred metrics for a modality from per-channel samples.
    /// For phone modalities, return on-device (or empty) results. For device
    /// modalities, return the clinical metrics from the cloud model (mocked).
    func infer(modality: Modality,
               channels: [SignalChannel: [Double]],
               sampleRate: Double,
               profile: HealthProfile?,
               skinTone: MonkSkinTone?) async -> InferenceResult
}

/// Routes each modality to the right inference engine and enforces the two trust
/// tiers: device-only clinical metrics (Hb, clinical SpO₂, anemia, perfusion,
/// hydration) may ONLY be attached for device modalities. Every cloud-derived
/// metric carries the model's attribution provenance.
///
/// Routing:
/// - `.deviceMultiWavelengthPPG` → cloud `encodePPG` (PaPaGei / Pulse-PPG):
///   hemoglobin, anemiaRisk, spo2Clinical, perfusionIndex + cloud provenance.
/// - `.deviceECG` → cloud `analyzeECG` (ECG-FM): refined rhythmIrregularity (and
///   heartRate) + cloud provenance.
/// - `.deviceBioZ` → on-device hydration estimate + on-device provenance.
/// - phone modalities → empty (DSP already produced everything), except optional
///   on-device CoreML rhythm screen for `.fingerPPG`.
public final class InferenceCoordinator: InferenceProviding {

    private let cloudClient: ModelClient
    private let onDevice: OnDeviceModels

    public init(cloudClient: ModelClient = CloudModelClient(),
                onDevice: OnDeviceModels = OnDeviceModels()) {
        self.cloudClient = cloudClient
        self.onDevice = onDevice
    }

    public func infer(modality: Modality,
                      channels: [SignalChannel: [Double]],
                      sampleRate: Double,
                      profile: HealthProfile?,
                      skinTone: MonkSkinTone?) async -> InferenceResult {
        switch modality {
        case .deviceMultiWavelengthPPG:
            return await inferMultiWavelengthPPG(channels: channels, sampleRate: sampleRate, profile: profile, skinTone: skinTone)
        case .deviceECG:
            return await inferECG(channels: channels, sampleRate: sampleRate, profile: profile, skinTone: skinTone)
        case .deviceBioZ:
            return inferBioZ(channels: channels, profile: profile)
        case .fingerPPG:
            return inferFingerPPGRhythmScreen(modality: modality, channels: channels, sampleRate: sampleRate, profile: profile)
        case .facialRPPG:
            // DSP already produced the supported metrics for these phone modalities.
            return .dspOnly
        }
    }

    // MARK: - Device: multi-wavelength PPG → cloud clinical metrics

    private func inferMultiWavelengthPPG(channels: [SignalChannel: [Double]],
                                         sampleRate: Double,
                                         profile: HealthProfile?,
                                         skinTone: MonkSkinTone?) async -> InferenceResult {
        let request = PPGEncodeRequest(
            channelSamples: channels,
            sampleRate: sampleRate,
            skinTone: (skinTone ?? profile?.monkSkinTone)?.value,
            profile: ModelProfileFields(profile: profile, skinTone: skinTone)
        )
        let modality = Modality.deviceMultiWavelengthPPG
        do {
            let response = try await cloudClient.encodePPG(request)
            let provenance = Provenance(
                engine: .cloud,
                modelName: response.modelName,
                modelVersion: response.modelVersion,
                attribution: response.attribution
            )
            // Build clinical metrics, each guarded against the modality's allow-list
            // so a device-only metric can never leak onto a non-device path.
            var metrics: [CardioMetric] = []
            appendIfSupported(&metrics, kind: .hemoglobin, value: response.hemoglobin, modality: modality, profile: profile)
            appendIfSupported(&metrics, kind: .anemiaRisk, value: response.anemiaRiskPercent, modality: modality, profile: profile)
            appendIfSupported(&metrics, kind: .spo2Clinical, value: response.spo2, modality: modality, profile: profile)
            appendIfSupported(&metrics, kind: .perfusionIndex, value: response.perfusionIndex, modality: modality, profile: profile)

            return InferenceResult(
                metrics: metrics,
                provenance: provenance,
                confidence: Confidence(response.confidence),
                interpretation: "Blood readings from the Heartelfie device. Screening insight, not a diagnosis."
            )
        } catch {
            // Offline / failure: no clinical metrics, but keep attribution provenance
            // so the UI can explain the pending state honestly.
            return InferenceResult(
                metrics: [],
                provenance: Provenance(engine: .cloud,
                                       modelName: "PaPaGei-PPG",
                                       modelVersion: "0.3-mock",
                                       attribution: "PaPaGei / Pulse-PPG encoder — result pending (offline). Real deployment must honor the model's data-license attribution."),
                confidence: nil,
                interpretation: Self.pendingNote(for: error)
            )
        }
    }

    // MARK: - Device: ECG → cloud rhythm analysis

    private func inferECG(channels: [SignalChannel: [Double]],
                          sampleRate: Double,
                          profile: HealthProfile?,
                          skinTone: MonkSkinTone?) async -> InferenceResult {
        let samples = channels[.ecg] ?? channels.values.first ?? []
        let request = ECGAnalysisRequest(
            samples: samples,
            sampleRate: sampleRate,
            leadConfiguration: "lead-I",
            skinTone: (skinTone ?? profile?.monkSkinTone)?.value,
            profile: ModelProfileFields(profile: profile, skinTone: skinTone)
        )
        let modality = Modality.deviceECG
        do {
            let response = try await cloudClient.analyzeECG(request)
            let provenance = Provenance(
                engine: .cloud,
                modelName: response.modelName,
                modelVersion: response.modelVersion,
                attribution: response.attribution
            )
            var metrics: [CardioMetric] = []
            // Refined rhythm irregularity from the ECG model.
            appendIfSupported(&metrics, kind: .rhythmIrregularity, value: response.irregularityPercent.rounded(),
                              modality: modality, profile: profile,
                              note: "Refined by \(response.modelName).")
            // Heart rate from the lead (more reliable than phone PPG).
            appendIfSupported(&metrics, kind: .heartRate, value: response.heartRate.rounded(),
                              modality: modality, profile: profile)

            return InferenceResult(
                metrics: metrics,
                provenance: provenance,
                confidence: Confidence(response.confidence),
                interpretation: "Rhythm: \(response.rhythmLabel). Screening insight from the Heartelfie device, not a diagnosis."
            )
        } catch {
            return InferenceResult(
                metrics: [],
                provenance: Provenance(engine: .cloud,
                                       modelName: "ECG-FM",
                                       modelVersion: "0.1-mock",
                                       attribution: "ECG-FM (reduced-lead finetune) — result pending (offline). Real deployment must honor the model's data-license attribution."),
                confidence: nil,
                interpretation: Self.pendingNote(for: error)
            )
        }
    }

    // MARK: - Device: BioZ → on-device hydration

    private func inferBioZ(channels: [SignalChannel: [Double]],
                           profile: HealthProfile?) -> InferenceResult {
        let modality = Modality.deviceBioZ
        let bioZ = channels[.bioImpedance] ?? channels.values.first ?? []
        let hydration = onDevice.estimateHydration(bioZ: bioZ)
        var metrics: [CardioMetric] = []
        appendIfSupported(&metrics, kind: .hydration, value: hydration, modality: modality, profile: profile,
                          note: "On-device estimate — placeholder model.")
        return InferenceResult(
            metrics: metrics,
            provenance: .onDeviceCoreML,
            confidence: Confidence(0.55),
            interpretation: "Hydration estimate from the Heartelfie device bio-impedance sensor."
        )
    }

    // MARK: - Phone: optional on-device CoreML rhythm screen for finger PPG

    private func inferFingerPPGRhythmScreen(modality: Modality,
                                            channels: [SignalChannel: [Double]],
                                            sampleRate: Double,
                                            profile: HealthProfile?) -> InferenceResult {
        // Use the same primary channel the DSP stage uses for finger PPG.
        let primary = SignalProcessor.primaryChannel(for: modality)
        guard let samples = channels[primary] ?? channels.values.first, samples.count > 8 else {
            return .dspOnly
        }
        let screen = onDevice.screenRhythm(samples: samples, sampleRate: sampleRate)
        // rhythmIrregularity is a phone-supported (non device-only) metric; still
        // guard against the modality allow-list for safety/consistency.
        guard modality.supportedMetrics.contains(.rhythmIrregularity) else { return .dspOnly }
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

    // MARK: - Helpers

    /// Append a metric ONLY if the modality legitimately supports its kind. This
    /// is the type-level enforcement of the trust-tier rule: device-only metrics
    /// can never be attached for a phone modality (and vice-versa).
    private func appendIfSupported(_ metrics: inout [CardioMetric],
                                   kind: MetricKind,
                                   value: Double,
                                   modality: Modality,
                                   profile: HealthProfile?,
                                   note: String? = nil) {
        guard modality.supportedMetrics.contains(kind) else { return }
        metrics.append(CardioMetric(kind: kind, value: value, note: note, profile: profile))
    }

    /// Honest, non-diagnostic note for a pending/offline cloud result.
    private static func pendingNote(for error: Error) -> String {
        if case ModelClientError.offlineQueued = error {
            return "Device reading queued — will complete when you're back online."
        }
        if case ModelClientError.retriesExhausted = error {
            return "Couldn't reach the Heartelfie cloud model. Your reading is saved and will retry."
        }
        return "Device clinical reading is temporarily unavailable. Your reading is saved."
    }
}
