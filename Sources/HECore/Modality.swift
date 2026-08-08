import Foundation

/// Every acquisition modality Heartelfie supports, each pinned to its trust
/// `tier`, physical `source`, and the set of metrics that source can legitimately
/// produce. This is the single source of truth for the acquisition matrix.
///
/// Phone modalities are `.screening`. Device modalities are `.measurement` and are
/// only usable when the Heartelfie hardware is connected with good contact.
public enum Modality: String, Codable, Sendable, CaseIterable, Hashable, Identifiable {
    /// Transmissive finger PPG via the rear camera + torch.
    case fingerPPG
    /// Contactless facial rPPG via the front camera + Vision face ROI.
    case facialRPPG
    /// Multi-wavelength PPG via the Heartelfie device.
    case deviceMultiWavelengthPPG
    /// ECG via the Heartelfie device electrodes. Device-only — never from phone.
    case deviceECG
    /// Bio-impedance (BioZ) via the Heartelfie device.
    case deviceBioZ

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .fingerPPG: return "Finger PPG"
        case .facialRPPG: return "Facial rPPG"
        case .deviceMultiWavelengthPPG: return "Multi-Wavelength PPG"
        case .deviceECG: return "Heart Rhythm"
        case .deviceBioZ: return "Bio-Impedance"
        }
    }

    public var shortName: String {
        switch self {
        case .fingerPPG: return "Finger PPG"
        case .facialRPPG: return "Face rPPG"
        case .deviceMultiWavelengthPPG: return "MW-PPG"
        case .deviceECG: return "Rhythm"
        case .deviceBioZ: return "BioZ"
        }
    }

    public var tier: MeasurementTier {
        switch self {
        case .fingerPPG, .facialRPPG:
            return .screening
        case .deviceMultiWavelengthPPG, .deviceECG, .deviceBioZ:
            return .measurement
        }
    }

    public var source: SignalSource {
        switch self {
        case .fingerPPG: return .rearCamera
        case .facialRPPG: return .frontCamera
        case .deviceMultiWavelengthPPG, .deviceECG, .deviceBioZ: return .device
        }
    }

    /// Retained for UI badging. No current modality is experimental.
    public var isExperimental: Bool { false }

    public var requiresDevice: Bool { source == .device }

    /// The metrics this modality is allowed to surface. Device-only metrics never
    /// appear under a phone modality — enforced at the type level.
    public var supportedMetrics: [MetricKind] {
        switch self {
        case .fingerPPG:
            return [.heartRate, .hrvSDNN, .hrvRMSSD, .rhythmIrregularity, .respiratoryRate]
        case .facialRPPG:
            return [.heartRate, .hrvSDNN, .hrvRMSSD]
        case .deviceMultiWavelengthPPG:
            return [.hemoglobin, .anemiaRisk, .spo2Clinical, .perfusionIndex, .heartRate]
        case .deviceECG:
            return [.heartRate, .rhythmIrregularity]
        case .deviceBioZ:
            return [.hydration]
        }
    }

    public var systemImage: String {
        switch self {
        case .fingerPPG: return "hand.point.up.left.fill"
        case .facialRPPG: return "face.smiling"
        case .deviceMultiWavelengthPPG: return "rays"
        case .deviceECG: return "waveform.path.ecg"
        case .deviceBioZ: return "drop.degreesign"
        }
    }

    /// One-line, non-diagnostic description of what the modality does.
    public var summary: String {
        switch self {
        case .fingerPPG:
            return "Place a fingertip over the rear camera and torch to screen heart rate and rhythm."
        case .facialRPPG:
            return "Look at the front camera for a contactless heart-rate screen."
        case .deviceMultiWavelengthPPG:
            return "Use the Heartelfie device clip for a multi-wavelength wellness reading."
        case .deviceECG:
            return "Hold the Heartelfie device electrodes for a heart-rhythm wellness reading."
        case .deviceBioZ:
            return "Use the Heartelfie device to estimate hydration via bio-impedance."
        }
    }

    /// The nominal sampling rate (Hz) the pipeline targets for this modality.
    public var nominalSampleRate: Double {
        switch self {
        case .fingerPPG, .facialRPPG: return 30      // video frame rate
        case .deviceMultiWavelengthPPG: return 125
        case .deviceECG: return 250
        case .deviceBioZ: return 50
        }
    }

    /// All phone-based screening modalities.
    public static var phoneModalities: [Modality] { allCases.filter { !$0.requiresDevice } }

    /// All device-based measurement modalities.
    public static var deviceModalities: [Modality] { allCases.filter(\.requiresDevice) }
}
