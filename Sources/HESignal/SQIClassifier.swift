import Foundation
import HECore

/// The Signal Quality Index gate. Runs **before** any metric is computed and is
/// the mechanism that enforces "never compute a metric from a rejected signal".
///
/// The headline score blends an autocorrelation-based periodicity measure (a clean
/// cardiac signal is strongly periodic in the plausible HR band) with amplitude,
/// clipping, and motion checks. Each failing check contributes a specific,
/// actionable `SQIIssue` so the UI can coach the user precisely.
public struct SQIClassifier: Sendable {

    public let acceptanceThreshold: Double

    public init(acceptanceThreshold: Double = ClinicalConfig.sqiAcceptanceThreshold) {
        self.acceptanceThreshold = acceptanceThreshold
    }

    /// Evaluate a (raw, unfiltered) signal for a given modality.
    /// - Parameters:
    ///   - raw: raw channel samples (DC included — needed for clipping/perfusion).
    ///   - filtered: band-pass filtered samples (cardiac band).
    ///   - sampleRate: sampling rate in Hz.
    ///   - durationSeconds: clean capture duration available.
    ///   - modality: modality (sets the expected HR search band / min duration).
    public func evaluate(
        raw: [Double],
        filtered: [Double],
        sampleRate: Double,
        durationSeconds: Double,
        modality: Modality
    ) -> SignalQuality {
        var issues: [SQIIssue] = []

        // 1. Duration check.
        let minDuration = ClinicalConfig.minimumCaptureSeconds(for: modality)
        if durationSeconds + 0.5 < minDuration {
            issues.append(.tooShort)
        }

        guard raw.count > 8, filtered.count > 8 else {
            return SignalQuality(sqi: 0, isAcceptable: false, issues: issues.isEmpty ? [.tooShort] : issues)
        }

        // 2. Amplitude / perfusion: AC range relative to DC level.
        let dc = abs(Vector.mean(raw))
        let acRange = Vector.maxValue(filtered) - Vector.minValue(filtered)
        let normalizedAmplitude = dc > 1e-6 ? acRange / dc : acRange
        let amplitudeScore = clamp01(normalizedAmplitude / amplitudeReference(for: modality))
        if amplitudeScore < 0.2 {
            issues.append(modality.source == .microphone ? .ambientNoise : .lowAmplitude)
        }

        // 3. Clipping / saturation: fraction of samples pinned at the extremes.
        let clipFraction = saturationFraction(raw)
        if clipFraction > 0.05 {
            issues.append(.saturation)
        }

        // 4. Motion: large transient jumps relative to typical step size.
        let motionScore = motionArtifactScore(raw)
        if motionScore > 0.35 {
            issues.append(.motion)
        }

        // 5. Periodicity: autocorrelation peak in the plausible HR lag band.
        let periodicity = periodicityScore(filtered, sampleRate: sampleRate, modality: modality)
        if periodicity < 0.3 {
            issues.append(.irregularCadence)
        }

        // Blend into a single 0...1 SQI (periodicity weighted most).
        let sqi = clamp01(
            0.50 * periodicity +
            0.25 * amplitudeScore +
            0.15 * (1 - motionScore) +
            0.10 * (1 - clipFraction)
        )

        let durationOK = durationSeconds + 0.5 >= minDuration
        let isAcceptable = sqi >= acceptanceThreshold && durationOK && !issues.contains(.saturation)

        // Order issues so the single most impactful fix comes first.
        let ordered = prioritise(issues)
        return SignalQuality(sqi: sqi, isAcceptable: isAcceptable, issues: ordered)
    }

    // MARK: - Components

    /// Normalised autocorrelation peak within the plausible heart-rate lag band.
    /// ~1 for a clean periodic cardiac signal, ~0 for noise.
    func periodicityScore(_ x: [Double], sampleRate: Double, modality: Modality) -> Double {
        let signal = Vector.zscore(x)
        let n = signal.count
        guard n > 16 else { return 0 }

        // Lag bounds from 30–220 bpm (period 0.27–2.0 s).
        let minLag = max(Int(sampleRate * 60.0 / 220.0), 1)
        let maxLag = min(Int(sampleRate * 60.0 / 30.0), n - 1)
        guard maxLag > minLag else { return 0 }

        let zeroLag = Vector.dot(signal, signal)
        guard zeroLag > 1e-9 else { return 0 }

        var best = 0.0
        for lag in minLag...maxLag {
            var acc = 0.0
            for i in 0..<(n - lag) {
                acc += signal[i] * signal[i + lag]
            }
            let normalized = acc / zeroLag
            if normalized > best { best = normalized }
        }
        return clamp01(best)
    }

    /// Fraction of samples within 0.5% of the observed min/max (proxy for clipping).
    func saturationFraction(_ x: [Double]) -> Double {
        guard !x.isEmpty else { return 0 }
        let lo = Vector.minValue(x)
        let hi = Vector.maxValue(x)
        let span = hi - lo
        guard span > 1e-9 else { return 1 } // flat-line == saturated/dead
        let tol = span * 0.005
        let pinned = x.filter { ($0 - lo) < tol || (hi - $0) < tol }.count
        return Double(pinned) / Double(x.count)
    }

    /// 0...1 motion-artifact score from the distribution of first differences.
    func motionArtifactScore(_ x: [Double]) -> Double {
        let d = Vector.diff(x).map(abs)
        guard !d.isEmpty else { return 0 }
        let median = Vector.median(d)
        guard median > 1e-9 else { return 0 }
        // Spikes many times the median step indicate motion.
        let spikes = d.filter { $0 > 6 * median }.count
        return clamp01(Double(spikes) / Double(d.count) * 8.0)
    }

    private func amplitudeReference(for modality: Modality) -> Double {
        switch modality {
        case .fingerPPG, .deviceMultiWavelengthPPG: return 0.02 // ~2% perfusion
        case .facialRPPG: return 0.005
        case .scg, .pcg: return 0.05
        case .deviceECG: return 0.1
        case .deviceBioZ: return 0.01
        }
    }

    private func prioritise(_ issues: [SQIIssue]) -> [SQIIssue] {
        let order: [SQIIssue] = [.noContact, .saturation, .motion, .lowLight, .lowAmplitude,
                                 .ambientNoise, .faceNotFound, .irregularCadence, .tooShort]
        let unique = Array(Set(issues))
        return unique.sorted { (order.firstIndex(of: $0) ?? 99) < (order.firstIndex(of: $1) ?? 99) }
    }

    private func clamp01(_ v: Double) -> Double { min(max(v, 0), 1) }
}
