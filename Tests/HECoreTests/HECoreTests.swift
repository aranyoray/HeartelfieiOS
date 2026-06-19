import XCTest
@testable import HECore

final class HECoreTests: XCTestCase {

    // MARK: Tier / modality honesty

    func testPhoneModalitiesAreScreeningTier() {
        for modality in Modality.phoneModalities {
            XCTAssertEqual(modality.tier, .screening, "\(modality) must be screening tier")
            XCTAssertFalse(modality.requiresDevice)
        }
    }

    func testDeviceModalitiesAreMeasurementTier() {
        for modality in Modality.deviceModalities {
            XCTAssertEqual(modality.tier, .measurement)
            XCTAssertTrue(modality.requiresDevice)
            XCTAssertEqual(modality.source, .device)
        }
    }

    /// The core constraint: phone modalities must never surface device-only metrics
    /// (ECG, clinical SpO₂, hemoglobin, etc.).
    func testPhoneModalitiesNeverExposeDeviceOnlyMetrics() {
        for modality in Modality.phoneModalities {
            for metric in modality.supportedMetrics {
                XCTAssertFalse(
                    metric.isDeviceOnly,
                    "\(modality) (phone) must not expose device-only metric \(metric)"
                )
            }
        }
    }

    func testModalityTierMatchesSensorTierContract() {
        for modality in Modality.allCases {
            // tier is derived from source; ensure they agree
            let expected: MeasurementTier = modality.source == .device ? .measurement : .screening
            XCTAssertEqual(modality.tier, expected)
        }
    }

    // MARK: MonkSkinTone

    func testMonkSkinToneRejectsOutOfRange() {
        XCTAssertNil(MonkSkinTone(value: 0))
        XCTAssertNil(MonkSkinTone(value: 11))
        XCTAssertNotNil(MonkSkinTone(value: 1))
        XCTAssertNotNil(MonkSkinTone(value: 10))
        XCTAssertEqual(MonkSkinTone.all.count, 10)
    }

    // MARK: Confidence

    func testConfidenceClampsAndBands() {
        XCTAssertEqual(Confidence(1.5).value, 1.0)
        XCTAssertEqual(Confidence(-0.5).value, 0.0)
        XCTAssertTrue(Confidence(0.2).isLow)
        XCTAssertEqual(Confidence(0.9).band, .high)
        XCTAssertEqual(Confidence(0.6).band, .moderate)
    }

    // MARK: ClinicalRange classification

    func testClinicalRangeClassification() {
        let range = ClinicalRange(low: 60, high: 100, unit: "bpm")
        XCTAssertEqual(range.classify(72), .normal)
        XCTAssertEqual(range.classify(105), .watch)   // within +25% margin
        XCTAssertEqual(range.classify(150), .elevated) // far above
        XCTAssertEqual(range.classify(58), .watch)
        XCTAssertEqual(range.classify(20), .elevated)
    }

    func testHemoglobinRangeVariesBySex() {
        let female = HealthProfile(biologicalSex: .female)
        let male = HealthProfile(biologicalSex: .male)
        let f = ClinicalConfig.referenceRange(for: .hemoglobin, profile: female)
        let m = ClinicalConfig.referenceRange(for: .hemoglobin, profile: male)
        XCTAssertNotNil(f)
        XCTAssertNotNil(m)
        XCTAssertNotEqual(f, m)
    }

    // MARK: Reading roll-ups

    func testOverallRiskIsWorstMetric() {
        let reading = CardioReading(
            modality: .fingerPPG,
            metrics: [
                CardioMetric(kind: .heartRate, value: 72),       // normal
                CardioMetric(kind: .rhythmIrregularity, value: 30) // elevated
            ],
            confidence: Confidence(0.8),
            signalQuality: .pristine,
            provenance: .onDeviceDSP,
            interpretation: ""
        )
        XCTAssertEqual(reading.overallRisk, .elevated)
    }

    func testReadingTierDefaultsToModalityTier() {
        let reading = CardioReading(
            modality: .deviceECG,
            metrics: [],
            confidence: Confidence(0.8),
            signalQuality: .pristine,
            provenance: .onDeviceDSP,
            interpretation: ""
        )
        XCTAssertEqual(reading.tier, .measurement)
    }

    // MARK: SeekCare signals

    func testSeekCareSignalsTriggerOnlyOutsideRange() {
        XCTAssertNil(ClinicalConfig.seekCareSignal(for: .heartRate, value: 70))
        XCTAssertNotNil(ClinicalConfig.seekCareSignal(for: .heartRate, value: 130))
        XCTAssertNotNil(ClinicalConfig.seekCareSignal(for: .spo2Clinical, value: 88))
        XCTAssertNil(ClinicalConfig.seekCareSignal(for: .spo2Clinical, value: 98))
    }

    // MARK: Codable round-trips

    func testReadingCodableRoundTrip() throws {
        let original = SampleData.fingerPPGReading()
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(CardioReading.self, from: data)
        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.metrics.count, original.metrics.count)
        XCTAssertEqual(decoded.tier, original.tier)
    }
}
