import XCTest
import HECore
@testable import HESignal

final class HESignalTests: XCTestCase {

    // MARK: - Vector math

    func testVectorBasics() {
        let x = [1.0, 2.0, 3.0, 4.0, 5.0]
        XCTAssertEqual(Vector.mean(x), 3.0, accuracy: 1e-9)
        XCTAssertEqual(Vector.sum(x), 15.0, accuracy: 1e-9)
        XCTAssertEqual(Vector.median(x), 3.0, accuracy: 1e-9)
        XCTAssertEqual(Vector.maxValue(x), 5.0, accuracy: 1e-9)
        XCTAssertEqual(Vector.minValue(x), 1.0, accuracy: 1e-9)
        XCTAssertEqual(Vector.std(x), 2.0.squareRoot(), accuracy: 1e-9)
    }

    func testZScoreHasZeroMeanUnitStd() {
        let x = (0..<100).map { sin(Double($0) * 0.3) + 5 }
        let z = Vector.zscore(x)
        XCTAssertEqual(Vector.mean(z), 0, accuracy: 1e-6)
        XCTAssertEqual(Vector.std(z), 1, accuracy: 1e-6)
    }

    // MARK: - Filtering

    func testBandpassRemovesDCOffset() {
        let dc = [Double](repeating: 3.0, count: 500)
        let filtered = BandpassFilter(lowHz: 0.7, highHz: 3.5, sampleRate: 100).filtfilt(dc)
        // After settling, a bandpass output should be ~0 for a pure DC input.
        let tail = Array(filtered.suffix(200))
        XCTAssertEqual(Vector.mean(tail), 0, accuracy: 1e-3)
    }

    func testBandpassPreservesInBandTone() {
        let fs = 100.0
        let tone = (0..<1000).map { sin(2 * .pi * 1.2 * Double($0) / fs) }
        let filtered = BandpassFilter(lowHz: 0.7, highHz: 3.5, sampleRate: fs).filtfilt(tone)
        // In-band energy should survive (amplitude not crushed).
        XCTAssertGreaterThan(Vector.std(filtered), 0.3)
    }

    // MARK: - Peak detection / HR

    func testPeakDetectionRecoversHeartRatePPG() {
        let fs = 100.0
        let hr = 72.0
        let signal = SyntheticSignal.ppg(durationSeconds: 20, sampleRate: fs, heartRateBPM: hr, hrvMS: 10, noise: 0.01)
        let filtered = BandpassFilter(lowHz: 0.7, highHz: 3.5, sampleRate: fs).filtfilt(signal)
        let detector = PeakDetector()
        let peaks = detector.peakIndices(in: filtered, sampleRate: fs)
        let rr = detector.rrIntervalsMS(peakIndices: peaks, sampleRate: fs)
        let metrics = RRMetrics(rrIntervalsMS: rr)
        XCTAssertNotNil(metrics)
        XCTAssertEqual(metrics!.heartRateBPM, hr, accuracy: 6)
    }

    func testPeakDetectionRecoversHeartRateECG() {
        let fs = 250.0
        let hr = 65.0
        let signal = SyntheticSignal.ecg(durationSeconds: 20, sampleRate: fs, heartRateBPM: hr, hrvMS: 8, noise: 0.01)
        let filtered = BandpassFilter(lowHz: 0.5, highHz: 40, sampleRate: fs).filtfilt(signal)
        let detector = PeakDetector()
        let peaks = detector.peakIndices(in: filtered, sampleRate: fs)
        let rr = detector.rrIntervalsMS(peakIndices: peaks, sampleRate: fs)
        let metrics = RRMetrics(rrIntervalsMS: rr)
        XCTAssertNotNil(metrics)
        XCTAssertEqual(metrics!.heartRateBPM, hr, accuracy: 6)
    }

    // MARK: - RR metrics

    func testRRMetricsConstantIntervals() {
        let rr = [Double](repeating: 800, count: 10) // 75 bpm, no variability
        let m = RRMetrics(rrIntervalsMS: rr)
        XCTAssertNotNil(m)
        XCTAssertEqual(m!.heartRateBPM, 75, accuracy: 0.01)
        XCTAssertEqual(m!.sdnnMS, 0, accuracy: 0.01)
        XCTAssertEqual(m!.rmssdMS, 0, accuracy: 0.01)
        XCTAssertEqual(m!.irregularityPercent, 0, accuracy: 0.01)
    }

    func testRRMetricsRejectsTooFewBeats() {
        XCTAssertNil(RRMetrics(rrIntervalsMS: [800, 810]))
    }

    func testRRMetricsFiltersImplausibleIntervals() {
        // 5000 ms is implausible and must be dropped.
        let rr = [800, 790, 810, 5000, 805, 795]
        let m = RRMetrics(rrIntervalsMS: rr.map(Double.init))
        XCTAssertNotNil(m)
        XCTAssertEqual(m!.beatCount, 5)
    }

    // MARK: - SQI gate

    func testSQIAcceptsCleanSignal() {
        let fs = 100.0
        let signal = SyntheticSignal.ppg(durationSeconds: 25, sampleRate: fs, heartRateBPM: 70, hrvMS: 10, noise: 0.01)
        let filtered = BandpassFilter(lowHz: 0.7, highHz: 3.5, sampleRate: fs).filtfilt(signal)
        let quality = SQIClassifier().evaluate(
            raw: signal, filtered: filtered, sampleRate: fs, durationSeconds: 25, modality: .fingerPPG
        )
        XCTAssertTrue(quality.isAcceptable, "Clean signal should pass SQI (sqi=\(quality.sqi))")
        XCTAssertGreaterThan(quality.sqi, ClinicalConfig.sqiAcceptanceThreshold)
    }

    func testSQIRejectsNoise() {
        let fs = 100.0
        var rng = SeededGenerator(seed: 99)
        let noise = (0..<2500).map { _ in rng.nextGaussian() }
        let filtered = BandpassFilter(lowHz: 0.7, highHz: 3.5, sampleRate: fs).filtfilt(noise)
        let quality = SQIClassifier().evaluate(
            raw: noise, filtered: filtered, sampleRate: fs, durationSeconds: 25, modality: .fingerPPG
        )
        XCTAssertFalse(quality.isAcceptable, "Pure noise must be rejected (sqi=\(quality.sqi))")
    }

    func testSQIRejectsTooShortCapture() {
        let fs = 100.0
        let signal = SyntheticSignal.ppg(durationSeconds: 3, sampleRate: fs, heartRateBPM: 70)
        let filtered = BandpassFilter(lowHz: 0.7, highHz: 3.5, sampleRate: fs).filtfilt(signal)
        let quality = SQIClassifier().evaluate(
            raw: signal, filtered: filtered, sampleRate: fs, durationSeconds: 3, modality: .fingerPPG
        )
        XCTAssertFalse(quality.isAcceptable)
        XCTAssertTrue(quality.issues.contains(.tooShort))
    }

    func testPeriodicityHigherForCleanThanNoise() {
        let fs = 100.0
        let clean = SyntheticSignal.ppg(durationSeconds: 15, sampleRate: fs, heartRateBPM: 70, noise: 0.01)
        let cleanF = BandpassFilter(lowHz: 0.7, highHz: 3.5, sampleRate: fs).filtfilt(clean)
        var rng = SeededGenerator(seed: 3)
        let noise = (0..<1500).map { _ in rng.nextGaussian() }
        let noiseF = BandpassFilter(lowHz: 0.7, highHz: 3.5, sampleRate: fs).filtfilt(noise)
        let classifier = SQIClassifier()
        let pClean = classifier.periodicityScore(cleanF, sampleRate: fs, modality: .fingerPPG)
        let pNoise = classifier.periodicityScore(noiseF, sampleRate: fs, modality: .fingerPPG)
        XCTAssertGreaterThan(pClean, pNoise)
        XCTAssertGreaterThan(pClean, 0.5)
    }

    // MARK: - End-to-end SignalProcessor

    func testSignalProcessorEndToEndPPG() {
        let fs = 100.0
        let hr = 76.0
        let signal = SyntheticSignal.ppg(durationSeconds: 25, sampleRate: fs, heartRateBPM: hr, hrvMS: 15, noise: 0.02)
        let result = SignalProcessor().process(
            channels: [.green: signal], sampleRate: fs, modality: .fingerPPG, profile: SampleData.profile
        )
        switch result {
        case .success(let processed):
            let hrMetric = processed.metrics.first { $0.kind == .heartRate }
            XCTAssertNotNil(hrMetric)
            XCTAssertEqual(hrMetric!.value, hr, accuracy: 6)
            // Phone PPG must never surface a device-only metric.
            XCTAssertFalse(processed.metrics.contains { $0.kind.isDeviceOnly })
            XCTAssertGreaterThan(processed.confidence.value, 0)
        case .failure(let error):
            XCTFail("Expected success, got \(error)")
        }
    }

    func testSignalProcessorRejectsPoorSignal() {
        let fs = 100.0
        var rng = SeededGenerator(seed: 5)
        let noise = (0..<2500).map { _ in rng.nextGaussian() * 0.1 }
        let result = SignalProcessor().process(
            channels: [.green: noise], sampleRate: fs, modality: .fingerPPG
        )
        switch result {
        case .success:
            XCTFail("Poor signal must not produce a reading")
        case .failure(let error):
            if case .poorSignalQuality = error { /* expected */ } else {
                XCTFail("Expected poorSignalQuality, got \(error)")
            }
        }
    }

    func testSignalProcessorScopesMetricsToModality() {
        let fs = 100.0
        let signal = SyntheticSignal.ppg(durationSeconds: 25, sampleRate: fs, heartRateBPM: 68, noise: 0.02)
        let result = SignalProcessor().process(
            channels: [.green: signal], sampleRate: fs, modality: .facialRPPG, profile: SampleData.profile
        )
        guard case .success(let processed) = result else {
            return XCTFail("Expected success")
        }
        let kinds = Set(processed.metrics.map(\.kind))
        XCTAssertTrue(kinds.isSubset(of: Set(Modality.facialRPPG.supportedMetrics)))
        XCTAssertTrue(kinds.contains(.heartRate))
    }

    func testSignalProcessorEmitsScreeningSpO2WhenRedAndGreenPresent() {
        let fs = 100.0
        let green = SyntheticSignal.ppg(durationSeconds: 25, sampleRate: fs, heartRateBPM: 72, hrvMS: 12, noise: 0.02)
        // Same pulsatile shape, different DC/AC so the ratio-of-ratios is defined.
        let red = green.map { $0 * 0.7 + 40 }
        let result = SignalProcessor().process(
            channels: [.green: green, .red: red],
            sampleRate: fs,
            modality: .fingerPPG,
            profile: SampleData.profile
        )
        guard case .success(let processed) = result else {
            return XCTFail("Expected success")
        }
        XCTAssertNotNil(processed.metrics.first { $0.kind == .spo2Estimate })
        XCTAssertFalse(processed.metrics.contains { $0.kind.isDeviceOnly })
    }

    func testSignalProcessorOmitsSpO2WhenNotSupported() {
        let fs = 100.0
        let green = SyntheticSignal.ppg(durationSeconds: 25, sampleRate: fs, heartRateBPM: 68, noise: 0.02)
        let red = green.map { $0 * 0.7 + 40 }
        let result = SignalProcessor().process(
            channels: [.green: green, .red: red],
            sampleRate: fs,
            modality: .facialRPPG,
            profile: SampleData.profile
        )
        guard case .success(let processed) = result else {
            return XCTFail("Expected success")
        }
        XCTAssertNil(processed.metrics.first { $0.kind == .spo2Estimate })
    }

    // MARK: - Audit regression tests

    /// Raw camera channels ride a large DC offset; the filter must not leave
    /// start/end transients big enough to swamp the pulse AC (peak-detector
    /// threshold + SQI amplitude both read the filtered signal's spread).
    func testFiltfiltHasNoEdgeTransientOnCameraLikeDC() {
        let sr = 30.0
        let n = 600
        let x = (0..<n).map { 150.0 + 20.0 * sin(2 * .pi * 1.2 * Double($0) / sr) }
        let filtered = BandpassFilter(lowHz: 0.7, highHz: 3.5, sampleRate: sr).filtfilt(x)
        XCTAssertEqual(filtered.count, n)
        let edge = Array(filtered.prefix(10)) + Array(filtered.suffix(10))
        for v in edge {
            XCTAssertLessThan(abs(v), 60, "edge transient should stay within pulse-AC order of magnitude")
        }
    }

    /// SDNN uses the sample (n−1) convention; population std biases small
    /// windows low enough to cross reference-range boundaries.
    func testRRMetricsSDNNUsesSampleStd() {
        let rr = [800.0, 850.0, 780.0, 830.0]
        let metrics = try! XCTUnwrap(RRMetrics(rrIntervalsMS: rr))
        let mean = rr.reduce(0, +) / 4
        let expected = (rr.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / 3).squareRoot()
        XCTAssertEqual(metrics.sdnnMS, expected, accuracy: 1e-9)
    }

    /// A rejected artifact must not stitch its neighbors into a fake
    /// "successive" pair for RMSSD.
    func testRRMetricsRMSSDSkipsPairsAcrossRejectedArtifacts() {
        let clean = [800.0, 810.0, 800.0, 810.0, 800.0]
        let base = try! XCTUnwrap(RRMetrics(rrIntervalsMS: clean))
        // Same beats with an implausible 100 ms artifact spliced into the middle.
        let spliced = [800.0, 810.0, 100.0, 800.0, 810.0, 800.0]
        let metrics = try! XCTUnwrap(RRMetrics(rrIntervalsMS: spliced))
        // The pair spanning the removed artifact (810 → 800) must be excluded,
        // so RMSSD is computed from strictly adjacent pairs only.
        XCTAssertEqual(metrics.beatCount, 5)
        XCTAssertLessThanOrEqual(metrics.rmssdMS, base.rmssdMS + 1e-9)
    }

    /// Non-positive sample rates must fail closed instead of producing NaN SQI.
    func testSignalProcessorRejectsNonPositiveSampleRate() {
        let samples = (0..<700).map { 150.0 + 20.0 * sin(Double($0) * 0.25) }
        let result = SignalProcessor().process(
            channels: [.green: samples], sampleRate: 0, modality: .fingerPPG
        )
        if case .failure(let error) = result {
            XCTAssertEqual(error, .sensorUnavailable)
        } else {
            XCTFail("expected failure for sampleRate == 0")
        }
    }
}
