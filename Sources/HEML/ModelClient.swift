import Foundation
import HECore

/// Abstract contract for the cloud model service that backs Heartelfie's
/// *device-tier* clinical inference (ECG rhythm analysis and multi-wavelength PPG
/// encoding). The contract is intentionally transport-agnostic so the
/// implementation can be a live `URLSession` client, a mock, or a future
/// on-device replacement without touching callers.
///
/// Every response carries `modelName` / `modelVersion` / `attribution` because the
/// underlying research models (ECG-FM, PaPaGei / Pulse-PPG) ship with
/// data-license **attribution obligations** that Heartelfie must surface to the
/// user on every cloud-derived result.
public protocol ModelClient: Sendable {
    /// Analyze a (reduced-lead) ECG buffer for rhythm. Device-tier only.
    func analyzeECG(_ request: ECGAnalysisRequest) async throws -> ECGAnalysisResponse
    /// Encode a multi-wavelength PPG buffer into clinical estimates
    /// (hemoglobin, anemia risk, clinical SpO₂, perfusion index). Device-tier only.
    func encodePPG(_ request: PPGEncodeRequest) async throws -> PPGEncodeResponse
}

// MARK: - Shared request fields

/// The minimal, privacy-respecting subset of `HealthProfile` the cloud models
/// consume. Kept as flat optional fields (not the full profile) to minimise the
/// PII that ever leaves the device, and to keep the wire format stable.
public struct ModelProfileFields: Codable, Sendable, Hashable {
    public let age: Int?
    public let biologicalSex: String?
    public let heightCM: Double?
    public let weightKG: Double?
    /// Monk Skin Tone position (1...10), disclosed and used to tune optical models.
    public let monkSkinTone: Int?

    public init(age: Int? = nil,
                biologicalSex: String? = nil,
                heightCM: Double? = nil,
                weightKG: Double? = nil,
                monkSkinTone: Int? = nil) {
        self.age = age
        self.biologicalSex = biologicalSex
        self.heightCM = heightCM
        self.weightKG = weightKG
        self.monkSkinTone = monkSkinTone
    }

    /// Project a `HealthProfile` (and optional explicit skin tone override) down to
    /// the wire fields. An explicit `skinTone` takes precedence over the profile's.
    public init(profile: HealthProfile?, skinTone: MonkSkinTone?) {
        self.age = profile?.age
        self.biologicalSex = profile?.biologicalSex?.rawValue
        self.heightCM = profile?.heightCM
        self.weightKG = profile?.weightKG
        self.monkSkinTone = (skinTone ?? profile?.monkSkinTone)?.value
    }
}

// MARK: - ECG (ECG-FM)

/// Request for cloud ECG rhythm analysis (ECG-FM reduced-lead finetune).
public struct ECGAnalysisRequest: Codable, Sendable, Hashable {
    /// Raw ECG samples (millivolts or ADC units; the service normalises).
    public let samples: [Double]
    /// Sampling rate of `samples`, in Hz.
    public let sampleRate: Double
    /// Lead configuration descriptor, e.g. "lead-I" for the device's single lead.
    public let leadConfiguration: String
    /// Self-reported skin tone (1...10), if shared. Optional.
    public let skinTone: Int?
    /// Flattened profile fields the model consumes.
    public let profile: ModelProfileFields

    public init(samples: [Double],
                sampleRate: Double,
                leadConfiguration: String = "lead-I",
                skinTone: Int? = nil,
                profile: ModelProfileFields = ModelProfileFields()) {
        self.samples = samples
        self.sampleRate = sampleRate
        self.leadConfiguration = leadConfiguration
        self.skinTone = skinTone
        self.profile = profile
    }
}

/// Response from cloud ECG rhythm analysis.
public struct ECGAnalysisResponse: Codable, Sendable, Hashable {
    /// Heart rate the model inferred (bpm).
    public let heartRate: Double
    /// Human-readable rhythm label, e.g. "Sinus rhythm".
    public let rhythmLabel: String
    /// Estimated proportion of irregular beats, as a percentage (0...100).
    public let irregularityPercent: Double
    /// Model confidence in `0...1`.
    public let confidence: Double
    /// Model name (attribution). Expected: "ECG-FM".
    public let modelName: String
    /// Model version string.
    public let modelVersion: String
    /// Attribution / license text that MUST be surfaced to the user.
    public let attribution: String

    public init(heartRate: Double,
                rhythmLabel: String,
                irregularityPercent: Double,
                confidence: Double,
                modelName: String,
                modelVersion: String,
                attribution: String) {
        self.heartRate = heartRate
        self.rhythmLabel = rhythmLabel
        self.irregularityPercent = irregularityPercent
        self.confidence = confidence
        self.modelName = modelName
        self.modelVersion = modelVersion
        self.attribution = attribution
    }
}

// MARK: - PPG (PaPaGei / Pulse-PPG)

/// Request for cloud multi-wavelength PPG encoding (PaPaGei / Pulse-PPG encoder).
public struct PPGEncodeRequest: Codable, Sendable, Hashable {
    /// Per-channel samples keyed by channel raw value (e.g. "red", "infrared").
    /// Keyed by `String` rather than `SignalChannel` so the wire format stays
    /// stable and self-describing.
    public let channels: [String: [Double]]
    /// Sampling rate of every channel, in Hz.
    public let sampleRate: Double
    /// Self-reported skin tone (1...10), if shared. Optical models use this to
    /// reduce melanin-driven bias; its use is disclosed to the user.
    public let skinTone: Int?
    /// Flattened profile fields the model consumes.
    public let profile: ModelProfileFields

    public init(channels: [String: [Double]],
                sampleRate: Double,
                skinTone: Int? = nil,
                profile: ModelProfileFields = ModelProfileFields()) {
        self.channels = channels
        self.sampleRate = sampleRate
        self.skinTone = skinTone
        self.profile = profile
    }

    /// Build from typed `SignalChannel` samples.
    public init(channelSamples: [SignalChannel: [Double]],
                sampleRate: Double,
                skinTone: Int? = nil,
                profile: ModelProfileFields = ModelProfileFields()) {
        var mapped: [String: [Double]] = [:]
        for (channel, samples) in channelSamples { mapped[channel.rawValue] = samples }
        self.init(channels: mapped, sampleRate: sampleRate, skinTone: skinTone, profile: profile)
    }
}

/// Response from cloud multi-wavelength PPG encoding — the clinical, device-tier
/// estimates. These metrics may ONLY ever be attached to a device modality.
public struct PPGEncodeResponse: Codable, Sendable, Hashable {
    /// Estimated hemoglobin concentration (g/dL).
    public let hemoglobin: Double
    /// Estimated anemia risk as a percentage (0...100).
    public let anemiaRiskPercent: Double
    /// Clinical-grade SpO₂ estimate as a percentage (0...100).
    public let spo2: Double
    /// Perfusion index as a percentage.
    public let perfusionIndex: Double
    /// Model confidence in `0...1`.
    public let confidence: Double
    /// Model name (attribution). Expected: "PaPaGei-PPG".
    public let modelName: String
    /// Model version string.
    public let modelVersion: String
    /// Attribution / license text that MUST be surfaced to the user.
    public let attribution: String

    public init(hemoglobin: Double,
                anemiaRiskPercent: Double,
                spo2: Double,
                perfusionIndex: Double,
                confidence: Double,
                modelName: String,
                modelVersion: String,
                attribution: String) {
        self.hemoglobin = hemoglobin
        self.anemiaRiskPercent = anemiaRiskPercent
        self.spo2 = spo2
        self.perfusionIndex = perfusionIndex
        self.confidence = confidence
        self.modelName = modelName
        self.modelVersion = modelVersion
        self.attribution = attribution
    }
}

// MARK: - Errors & pending state

/// Errors surfaced by the cloud model layer.
public enum ModelClientError: Error, Sendable, Equatable {
    /// The device appears to be offline and the request was enqueued for retry.
    case offlineQueued
    /// The service returned a non-success HTTP status.
    case httpStatus(Int)
    /// The response body could not be decoded.
    case decodingFailed
    /// The request exhausted its retry budget.
    case retriesExhausted
    /// TLS certificate pinning rejected the server.
    case certificatePinningFailed
    /// The request was malformed (e.g. empty sample buffer).
    case invalidRequest
}
