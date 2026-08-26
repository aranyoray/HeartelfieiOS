import Foundation

/// Every cardiovascular metric Heartelfie can surface, scoped to what each source
/// legitimately supports. Note the deliberate split between *screening* SpO₂
/// (`spo2Estimate`, phone-only, labelled approximate) and *clinical* SpO₂
/// (`spo2Clinical`, device-only).
public enum MetricKind: String, Codable, Sendable, CaseIterable, Hashable, Identifiable {
    case heartRate
    case hrvSDNN
    case hrvRMSSD
    case rhythmIrregularity
    case spo2Estimate          // screening, phone — approximate
    case spo2Clinical          // measurement, device — clinical-grade
    case hemoglobin            // device only
    case anemiaRisk            // device only
    case perfusionIndex        // device only
    case hydration             // device only (bio-impedance)
    case respiratoryRate

    public var id: String { rawValue }

    /// User-facing labels are deliberately **wellness-framed** (non-diagnostic) so
    /// the app can ship on consumer app stores: no metric name asserts a clinical
    /// measurement or diagnosis. The underlying `rawValue` keys are unchanged, so
    /// persistence, ML routing, and device gating are unaffected.
    public var displayName: String {
        switch self {
        case .heartRate: return "Heart Rate"
        case .hrvSDNN: return "HRV (SDNN)"
        case .hrvRMSSD: return "HRV (RMSSD)"
        case .rhythmIrregularity: return "Rhythm Variation"
        case .spo2Estimate: return "Oxygen Wellness (approx.)"
        case .spo2Clinical: return "Oxygen Wellness"
        case .hemoglobin: return "Oxygen-Carry Wellness"
        case .anemiaRisk: return "Iron-Level Wellness"
        case .perfusionIndex: return "Perfusion Wellness"
        case .hydration: return "Hydration Wellness"
        case .respiratoryRate: return "Breathing Rate"
        }
    }

    /// Short label for compact metric chips.
    public var shortName: String {
        switch self {
        case .heartRate: return "HR"
        case .hrvSDNN: return "HRV·SDNN"
        case .hrvRMSSD: return "HRV·RMSSD"
        case .rhythmIrregularity: return "Rhythm"
        case .spo2Estimate, .spo2Clinical: return "O₂"
        case .hemoglobin: return "O₂-Carry"
        case .anemiaRisk: return "Iron"
        case .perfusionIndex: return "Perfusion"
        case .hydration: return "Hydration"
        case .respiratoryRate: return "Breath"
        }
    }

    public var unit: String {
        switch self {
        case .heartRate: return "bpm"
        case .hrvSDNN, .hrvRMSSD: return "ms"
        case .rhythmIrregularity: return "%"
        case .spo2Estimate, .spo2Clinical: return "%"
        case .hemoglobin: return "g/dL"
        case .anemiaRisk: return "%"
        case .perfusionIndex: return "%"
        case .hydration: return "%"
        case .respiratoryRate: return "br/min"
        }
    }

    public var systemImage: String {
        switch self {
        case .heartRate: return "heart.fill"
        case .hrvSDNN, .hrvRMSSD: return "waveform.path.ecg"
        case .rhythmIrregularity: return "waveform.path.ecg.rectangle"
        case .spo2Estimate, .spo2Clinical: return "drop.degreesign.fill"
        case .hemoglobin: return "drop.fill"
        case .anemiaRisk: return "drop.triangle"
        case .perfusionIndex: return "wave.3.right"
        case .hydration: return "humidity.fill"
        case .respiratoryRate: return "lungs.fill"
        }
    }

    /// Whether this metric may only ever be produced by the hardware device.
    /// Enforced so phone-only sensors can never label an ECG / clinical SpO₂ / Hb.
    public var isDeviceOnly: Bool {
        switch self {
        case .spo2Clinical, .hemoglobin, .anemiaRisk, .perfusionIndex, .hydration:
            return true
        default:
            return false
        }
    }

    /// Number of decimal places to show for the metric value.
    public var fractionDigits: Int {
        switch self {
        case .heartRate, .respiratoryRate, .spo2Estimate, .spo2Clinical,
             .rhythmIrregularity, .anemiaRisk, .hydration:
            return 0
        case .hrvSDNN, .hrvRMSSD:
            return 0
        case .hemoglobin, .perfusionIndex:
            return 1
        }
    }
}
