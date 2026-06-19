import Foundation

/// An inclusive `[low, high]` reference band for a metric, with risk classification.
public struct ClinicalRange: Codable, Sendable, Hashable {
    public let low: Double
    public let high: Double
    public let unit: String

    public init(low: Double, high: Double, unit: String) {
        self.low = low
        self.high = high
        self.unit = unit
    }

    /// Classify a value into a softened risk level. Values just outside the band
    /// are `.watch`; far outside (±25% of the band's span) are `.elevated`.
    public func classify(_ value: Double) -> RiskLevel {
        guard high > low else { return .unknown }
        if value >= low && value <= high { return .normal }
        let span = high - low
        let margin = span * 0.25
        if value < low {
            return value >= (low - margin) ? .watch : .elevated
        } else {
            return value <= (high + margin) ? .watch : .elevated
        }
    }

    public var displayString: String {
        "\(Int(low.rounded()))–\(Int(high.rounded())) \(unit)"
    }
}

/// ⚠️ PLACEHOLDER CLINICAL CONFIGURATION ⚠️
///
/// This is the **single source of truth** for every reference range, threshold,
/// and gate Heartelfie uses. Every number here is an illustrative placeholder for
/// a wellness/screening product — **not** validated medical guidance. Replace
/// these with values reviewed by qualified clinicians before any real-world use.
///
/// Nothing elsewhere in the codebase may hard-code a medical threshold; it must
/// reference this type.
public enum ClinicalConfig {

    // MARK: - Pipeline gates

    /// Minimum SQI a capture must reach to be accepted (0...1).
    public static let sqiAcceptanceThreshold: Double = 0.6

    /// Confidence at/below which a reading is treated as "low confidence".
    public static let lowConfidenceThreshold: Double = 0.5

    /// Minimum clean capture duration (seconds) before metrics may be computed.
    public static func minimumCaptureSeconds(for modality: Modality) -> Double {
        switch modality {
        case .fingerPPG, .facialRPPG, .deviceMultiWavelengthPPG: return 20
        case .scg, .pcg: return 15
        case .deviceECG: return 30
        case .deviceBioZ: return 5
        }
    }

    // MARK: - Reference ranges (placeholders)

    /// Reference range for a metric, optionally personalised by profile.
    /// Returns `nil` for metrics without a meaningful numeric band (e.g. flags).
    public static func referenceRange(for kind: MetricKind, profile: HealthProfile? = nil) -> ClinicalRange? {
        switch kind {
        case .heartRate:
            return ClinicalRange(low: 60, high: 100, unit: "bpm")
        case .hrvSDNN:
            return ClinicalRange(low: 30, high: 120, unit: "ms")
        case .hrvRMSSD:
            return ClinicalRange(low: 20, high: 100, unit: "ms")
        case .rhythmIrregularity:
            return ClinicalRange(low: 0, high: 5, unit: "%")
        case .spo2Estimate, .spo2Clinical:
            return ClinicalRange(low: 95, high: 100, unit: "%")
        case .hemoglobin:
            // Coarse placeholder; real ranges differ by age/sex/pregnancy.
            if profile?.biologicalSex == .female {
                return ClinicalRange(low: 12.0, high: 15.5, unit: "g/dL")
            }
            return ClinicalRange(low: 13.5, high: 17.5, unit: "g/dL")
        case .anemiaRisk:
            return ClinicalRange(low: 0, high: 20, unit: "%")
        case .perfusionIndex:
            return ClinicalRange(low: 0.5, high: 5.0, unit: "%")
        case .hydration:
            return ClinicalRange(low: 50, high: 65, unit: "%")
        case .respiratoryRate:
            return ClinicalRange(low: 12, high: 20, unit: "br/min")
        case .beatTiming:
            return nil
        case .murmurFlag:
            return nil
        }
    }

    /// Convenience: classify a value for a metric against its reference range.
    public static func risk(for kind: MetricKind, value: Double, profile: HealthProfile? = nil) -> RiskLevel {
        guard let range = referenceRange(for: kind, profile: profile) else { return .unknown }
        return range.classify(value)
    }

    // MARK: - Screening estimation calibration (placeholders)

    /// Rough ratio-of-ratios calibration for the **phone SpO₂ estimate** only.
    /// Phones lack a true IR channel, so this is an approximation labelled as such
    /// in the UI. Intercept/slope are placeholders — replace with a calibrated fit.
    public static let spo2EstimateIntercept: Double = 104
    public static let spo2EstimateSlope: Double = 17

    /// Map a red/green ratio-of-ratios to an approximate SpO₂ percentage, clamped
    /// to a plausible screening range. Placeholder calibration.
    public static func estimatedSpO2(ratioOfRatios r: Double) -> Double {
        let estimate = spo2EstimateIntercept - spo2EstimateSlope * r
        return min(max(estimate, 70), 100)
    }

    // MARK: - BMI categories (placeholders)

    /// Map a BMI value to a softened, non-diagnostic category + risk band.
    /// Standard adult cut-points used as labelled placeholders — replace/contextualise
    /// (age, pregnancy, athleticism, ethnicity-specific cut-points) before real use.
    public static func bmiCategory(_ bmi: Double) -> (label: String, risk: RiskLevel) {
        switch bmi {
        case ..<18.5: return ("Underweight", .watch)
        case ..<25: return ("Healthy range", .normal)
        case ..<30: return ("Overweight", .watch)
        default: return ("Higher range", .elevated)
        }
    }

    // MARK: - "When to seek care" signals (configurable, labelled placeholders)

    /// Non-diagnostic guidance thresholds that, when crossed, surface a gentle
    /// "consider seeking care" prompt in Insights. Labelled placeholders.
    public struct SeekCareSignal: Sendable, Hashable {
        public let kind: MetricKind
        public let message: String
    }

    public static func seekCareSignal(for kind: MetricKind, value: Double) -> SeekCareSignal? {
        switch kind {
        case .spo2Estimate, .spo2Clinical:
            guard value < 92 else { return nil }
            return SeekCareSignal(kind: kind, message: "Repeated low oxygen screenings are worth discussing with a clinician.")
        case .heartRate:
            guard value > 120 || value < 40 else { return nil }
            return SeekCareSignal(kind: kind, message: "A resting heart rate this far outside the typical range is worth a professional check.")
        case .rhythmIrregularity:
            guard value > 15 else { return nil }
            return SeekCareSignal(kind: kind, message: "Frequent rhythm irregularities are worth reviewing with a clinician.")
        default:
            return nil
        }
    }
}
