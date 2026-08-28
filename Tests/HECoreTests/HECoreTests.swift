import XCTest
@testable import HECore

final class HECoreTests: XCTestCase {

    // MARK: Tier / modality honesty

    func testPhoneModalitiesAreScreeningTier() {
        for modality in Modality.allCases {
            XCTAssertEqual(modality.tier, .screening, "\(modality) must be screening tier")
        }
    }

    /// The core constraint: phone modalities must never surface device-only or
    /// hidden legacy metrics (ECG, hemoglobin, etc.).
    func testPhoneModalitiesNeverExposeDeviceOnlyMetrics() {
        for modality in Modality.allCases {
            for metric in modality.supportedMetrics {
                XCTAssertFalse(
                    metric.isDeviceOnly,
                    "\(modality) (phone) must not expose device-only metric \(metric)"
                )
            }
        }
    }

    func testPhoneModalitiesDoNotSurfaceLegacySpO2Metrics() {
        XCTAssertFalse(Modality.fingerPPG.supportedMetrics.contains(.spo2Estimate))
        XCTAssertFalse(Modality.fingerPPG.supportedMetrics.contains(.spo2Clinical))
        XCTAssertFalse(Modality.facialRPPG.supportedMetrics.contains(.spo2Estimate))
        XCTAssertFalse(Modality.facialRPPG.supportedMetrics.contains(.spo2Clinical))
    }

    func testModalityTierMatchesSensorTierContract() {
        XCTAssertEqual(Modality.fingerPPG.source, .rearCamera)
        XCTAssertEqual(Modality.facialRPPG.source, .frontCamera)
        for modality in Modality.allCases {
            XCTAssertEqual(modality.tier, .screening)
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

    func testHiddenLegacyOxygenMetricsDoNotAffectVisibleReadingRisk() {
        let reading = CardioReading(
            modality: .fingerPPG,
            metrics: [
                CardioMetric(kind: .heartRate, value: 72),
                CardioMetric(kind: .spo2Clinical, value: 88)
            ],
            confidence: Confidence(0.8),
            signalQuality: .pristine,
            provenance: .onDeviceDSP,
            interpretation: ""
        )

        XCTAssertEqual(reading.visibleMetrics.map(\.kind), [.heartRate])
        XCTAssertEqual(reading.overallRisk, .normal)
    }

    func testReadingTierDefaultsToModalityTier() {
        let reading = CardioReading(
            modality: .fingerPPG,
            metrics: [],
            confidence: Confidence(0.8),
            signalQuality: .pristine,
            provenance: .onDeviceDSP,
            interpretation: ""
        )
        XCTAssertEqual(reading.tier, .screening)
    }

    // MARK: SeekCare signals

    func testSeekCareSignalsTriggerOnlyOutsideRange() {
        XCTAssertNil(ClinicalConfig.seekCareSignal(for: .heartRate, value: 70))
        XCTAssertNotNil(ClinicalConfig.seekCareSignal(for: .heartRate, value: 130))
        XCTAssertNil(ClinicalConfig.seekCareSignal(for: .spo2Clinical, value: 88))
        XCTAssertNil(ClinicalConfig.seekCareSignal(for: .spo2Clinical, value: 98))
    }

    // MARK: Codable round-trips

    func testLegacyDeviceModalityDecodesAsFingerPPG() throws {
        let json = "\"deviceECG\"".data(using: .utf8)!
        let decoded = try JSONDecoder().decode(Modality.self, from: json)
        XCTAssertEqual(decoded, .fingerPPG)
    }

    func testReadingCodableRoundTrip() throws {
        let original = SampleData.fingerPPGReading()
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(CardioReading.self, from: data)
        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.metrics.count, original.metrics.count)
        XCTAssertEqual(decoded.tier, original.tier)
    }

    func testMergingInferredMetricsReplacesSameKind() {
        let dsp = [
            CardioMetric(kind: .heartRate, value: 72),
            CardioMetric(kind: .rhythmIrregularity, value: 4)
        ]
        let inferred = [
            CardioMetric(kind: .rhythmIrregularity, value: 18, note: "On-device rhythm screen")
        ]
        let merged = CardioMetric.merging(dsp, withInferred: inferred)
        XCTAssertEqual(merged.count, 2)
        XCTAssertEqual(merged.first { $0.kind == .heartRate }?.value, 72)
        let rhythm = merged.first { $0.kind == .rhythmIrregularity }
        XCTAssertEqual(rhythm?.value, 18)
        XCTAssertEqual(rhythm?.note, "On-device rhythm screen")
    }

    func testMergingInferredMetricsAppendsNewKinds() {
        let dsp = [CardioMetric(kind: .heartRate, value: 70)]
        let inferred = [CardioMetric(kind: .rhythmIrregularity, value: 3)]
        let merged = CardioMetric.merging(dsp, withInferred: inferred)
        XCTAssertEqual(Set(merged.map(\.kind)), [.heartRate, .rhythmIrregularity])
    }

    // MARK: HealthProfile (name / BMI / conditions)

    func testProfileDefaultsToParticipantID() {
        XCTAssertEqual(HealthProfile().name, "PID001")
        // Empty names fall back to the participant ID.
        XCTAssertEqual(HealthProfile(name: "").name, "PID001")
    }

    func testBMIComputation() throws {
        let profile = HealthProfile(heightCM: 168, weightKG: 63)
        let bmi = try XCTUnwrap(profile.bmi)
        XCTAssertEqual(bmi, 22.3, accuracy: 0.1)
        XCTAssertNil(HealthProfile(heightCM: nil, weightKG: 63).bmi)
    }

    func testBMICategoryBands() {
        XCTAssertEqual(ClinicalConfig.bmiCategory(17).risk, .watch)
        XCTAssertEqual(ClinicalConfig.bmiCategory(22).risk, .normal)
        XCTAssertEqual(ClinicalConfig.bmiCategory(27).risk, .watch)
        XCTAssertEqual(ClinicalConfig.bmiCategory(33).risk, .elevated)
    }

    func testPriorConditionsRoundTrip() throws {
        var profile = HealthProfile(race: .asian)
        profile.priorConditions = [.hypertension, .cardiac]
        let data = try JSONEncoder().encode(profile)
        let decoded = try JSONDecoder().decode(HealthProfile.self, from: data)
        XCTAssertEqual(decoded.priorConditions, [.hypertension, .cardiac])
        XCTAssertEqual(decoded.race, .asian)
    }

    /// Profiles saved before the new fields existed must still decode, defaulting
    /// the missing keys rather than failing.
    func testProfileDecodingResilientToMissingKeys() throws {
        let legacyJSON = """
        { "age": 40, "knownConditions": [], "unitSystem": "metric" }
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(HealthProfile.self, from: legacyJSON)
        XCTAssertEqual(decoded.name, "PID001")
        XCTAssertEqual(decoded.age, 40)
        XCTAssertTrue(decoded.priorConditions.isEmpty)
        XCTAssertNil(decoded.race)
        XCTAssertEqual(decoded.unitSystem, .metric)
    }

    // MARK: Audit regression tests

    /// The documented contract is "at/below the threshold is low"; the band
    /// switch must be inclusive at the boundary so the recheck pathway fires.
    func testConfidenceBandLowBoundaryIsInclusive() {
        let atThreshold = Confidence(ClinicalConfig.lowConfidenceThreshold)
        XCTAssertEqual(atThreshold.band, ConfidenceBand.low)
        let justAbove = Confidence(ClinicalConfig.lowConfidenceThreshold + 0.01)
        XCTAssertEqual(justAbove.band, ConfidenceBand.moderate)
    }
}
