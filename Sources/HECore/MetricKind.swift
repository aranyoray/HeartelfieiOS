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
    case beatTiming
    case murmurFlag            // experimental phone PCG screen

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .heartRate: return "Heart Rate"
        case .hrvSDNN: return "HRV (SDNN)"
        case .hrvRMSSD: return "HRV (RMSSD)"
        case .rhythmIrregularity: return "Rhythm Irregularity"
        case .spo2Estimate: return "SpO₂ (approx.)"
        case .spo2Clinical: return "Blood Oxygen"
        case .hemoglobin: return "Hemoglobin"
        case .anemiaRisk: return "Anemia Risk"
        case .perfusionIndex: return "Perfusion Index"
        case .hydration: return "Hydration"
        case .respiratoryRate: return "Respiratory Rate"
        case .beatTiming: return "Beat Timing"
        case .murmurFlag: return "Heart-Sound Flag"
        }
    }

    /// Short label for compact metric chips.
    public var shortName: String {
        switch self {
        case .heartRate: return "HR"
        case .hrvSDNN: return "SDNN"
        case .hrvRMSSD: return "RMSSD"
        case .rhythmIrregularity: return "Rhythm"
        case .spo2Estimate, .spo2Clinical: return "SpO₂"
        case .hemoglobin: return "Hb"
        case .anemiaRisk: return "Anemia"
        case .perfusionIndex: return "PI"
        case .hydration: return "Hydration"
        case .respiratoryRate: return "Resp"
        case .beatTiming: return "Beat"
        case .murmurFlag: return "Sound"
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
        case .beatTiming: return "ms"
        case .murmurFlag: return ""
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
        case .beatTiming: return "metronome.fill"
        case .murmurFlag: return "ear.badge.waveform"
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
        case .hrvSDNN, .hrvRMSSD, .beatTiming:
            return 0
        case .hemoglobin, .perfusionIndex:
            return 1
        case .murmurFlag:
            return 0
        }
    }
}
