import Foundation

/// Shared, deterministic sample domain data for SwiftUI previews, mock sensors,
/// and seeding demo history. Centralised so every module shows consistent data.
public enum SampleData {

    public static let profile = HealthProfile(
        name: "PID001",
        age: 34,
        biologicalSex: .female,
        heightCM: 168,
        weightKG: 63,
        race: .asian,
        knownConditions: [],
        priorConditions: [.hypertension],
        monkSkinTone: MonkSkinTone(value: 6),
        unitSystem: .metric
    )

    /// A clean finger-PPG screening reading.
    public static func fingerPPGReading(at date: Date = Date()) -> CardioReading {
        CardioReading(
            timestamp: date,
            modality: .fingerPPG,
            metrics: [
                CardioMetric(kind: .heartRate, value: 72, profile: profile),
                CardioMetric(kind: .hrvSDNN, value: 58, profile: profile),
                CardioMetric(kind: .hrvRMSSD, value: 42, profile: profile),
                CardioMetric(kind: .rhythmIrregularity, value: 2, profile: profile),
                CardioMetric(kind: .spo2Estimate, value: 97, note: "Approximate — screening only", profile: profile)
            ],
            confidence: Confidence(0.82),
            signalQuality: SignalQuality(sqi: 0.88, isAcceptable: true, issues: []),
            provenance: .onDeviceDSP,
            interpretation: "Your heart rate and variability look typical for a relaxed reading. Keep tracking the trend.",
            monkSkinTone: profile.monkSkinTone,
            waveformPreview: syntheticWave(count: 120)
        )
    }

    /// A device multi-wavelength measurement reading.
    public static func deviceReading(at date: Date = Date()) -> CardioReading {
        CardioReading(
            timestamp: date,
            modality: .deviceMultiWavelengthPPG,
            metrics: [
                CardioMetric(kind: .hemoglobin, value: 13.6, profile: profile),
                CardioMetric(kind: .anemiaRisk, value: 8, profile: profile),
                CardioMetric(kind: .spo2Clinical, value: 98, profile: profile),
                CardioMetric(kind: .perfusionIndex, value: 2.4, profile: profile),
                CardioMetric(kind: .heartRate, value: 70, profile: profile)
            ],
            confidence: Confidence(0.91),
            signalQuality: SignalQuality(sqi: 0.94, isAcceptable: true, issues: []),
            provenance: Provenance(
                engine: .cloud,
                modelName: "PaPaGei-PPG",
                modelVersion: "0.3-mock",
                attribution: "PPG foundation model — mock response. Attribution required in production."
            ),
            interpretation: "Your multi-wavelength wellness reading looks typical. Oxygen-carry and oxygen wellness estimates are within the configured range.",
            monkSkinTone: profile.monkSkinTone,
            waveformPreview: syntheticWave(count: 120)
        )
    }

    /// A low-confidence reading that should trigger the recheck pathway.
    public static func lowConfidenceReading(at date: Date = Date()) -> CardioReading {
        CardioReading(
            timestamp: date,
            modality: .facialRPPG,
            metrics: [
                CardioMetric(kind: .heartRate, value: 88, profile: profile),
                CardioMetric(kind: .hrvSDNN, value: 31, profile: profile)
            ],
            confidence: Confidence(0.38),
            signalQuality: SignalQuality(sqi: 0.62, isAcceptable: true, issues: [.motion]),
            provenance: .onDeviceDSP,
            interpretation: "Confidence on this contactless reading was low. Try again holding still in even light.",
            monkSkinTone: profile.monkSkinTone,
            waveformPreview: syntheticWave(count: 120)
        )
    }

    /// A small history spanning several days for Trends previews.
    public static func history(days: Int = 14) -> [CardioReading] {
        let calendar = Calendar.current
        var readings: [CardioReading] = []
        for dayOffset in 0..<days {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: Date()) else { continue }
            // Skip a couple of days to make the streak/heatmap realistic.
            if dayOffset == 3 || dayOffset == 8 { continue }
            let jitter = Double((dayOffset * 7) % 13) - 6
            readings.append(
                CardioReading(
                    timestamp: date,
                    modality: dayOffset % 4 == 0 ? .deviceMultiWavelengthPPG : .fingerPPG,
                    metrics: [
                        CardioMetric(kind: .heartRate, value: 70 + jitter, profile: profile),
                        CardioMetric(kind: .hrvSDNN, value: 55 + jitter, profile: profile)
                    ],
                    confidence: Confidence(0.7 + Double(dayOffset % 3) * 0.08),
                    signalQuality: SignalQuality(sqi: 0.85, isAcceptable: true, issues: []),
                    provenance: .onDeviceDSP,
                    interpretation: "Daily check.",
                    monkSkinTone: profile.monkSkinTone
                )
            )
        }
        return readings
    }

    /// A simple synthetic PPG-like waveform for previews.
    public static func syntheticWave(count: Int) -> [Double] {
        (0..<count).map { i in
            let t = Double(i) / Double(count)
            let beat = sin(2 * .pi * t * 8)
            let dicrotic = 0.3 * sin(2 * .pi * t * 16 + 0.6)
            return beat + dicrotic
        }
    }
}
