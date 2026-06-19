import Foundation

/// Deterministic, seedable RNG (SplitMix64) so synthetic signals and tests are
/// reproducible.
public struct SeededGenerator: RandomNumberGenerator, Sendable {
    private var state: UInt64
    public init(seed: UInt64 = 0x9E3779B97F4A7C15) { self.state = seed }

    public mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }

    /// Standard-normal sample via Box–Muller.
    public mutating func nextGaussian() -> Double {
        let u1 = Double.random(in: 1e-12...1, using: &self)
        let u2 = Double.random(in: 0...1, using: &self)
        return (-2 * log(u1)).squareRoot() * cos(2 * .pi * u2)
    }
}

/// Realistic synthetic waveform generators used by both the DSP unit tests and the
/// mock sensors. Configurable noise, motion artifact, and baseline wander let the
/// SQI / HR / rhythm logic be exercised and demoed without hardware.
public enum SyntheticSignal {

    /// Generate a synthetic PPG waveform with dicrotic-notch morphology.
    public static func ppg(
        durationSeconds: Double,
        sampleRate: Double,
        heartRateBPM: Double = 72,
        hrvMS: Double = 25,
        noise: Double = 0.0,
        motionArtifact: Double = 0.0,
        baselineWander: Double = 0.05,
        seed: UInt64 = 42
    ) -> [Double] {
        var rng = SeededGenerator(seed: seed)
        let count = Int(durationSeconds * sampleRate)
        guard count > 0 else { return [] }

        let beatTimes = generateBeatTimes(
            duration: durationSeconds, heartRateBPM: heartRateBPM, hrvMS: hrvMS, rng: &rng
        )

        var signal = [Double](repeating: 0, count: count)
        for i in 0..<count {
            let t = Double(i) / sampleRate
            var v = 0.0
            for beat in beatTimes where abs(t - beat) < 1.2 {
                v += ppgPulse(t - beat)
            }
            v += baselineWander * sin(2 * .pi * 0.2 * t)        // respiration
            if noise > 0 { v += noise * rng.nextGaussian() }
            signal[i] = v
        }

        if motionArtifact > 0 {
            injectMotion(into: &signal, sampleRate: sampleRate, amplitude: motionArtifact, rng: &rng)
        }
        return signal
    }

    /// Generate a synthetic ECG (PQRST) waveform with HR variability.
    public static func ecg(
        durationSeconds: Double,
        sampleRate: Double,
        heartRateBPM: Double = 72,
        hrvMS: Double = 25,
        noise: Double = 0.0,
        baselineWander: Double = 0.05,
        seed: UInt64 = 7
    ) -> [Double] {
        var rng = SeededGenerator(seed: seed)
        let count = Int(durationSeconds * sampleRate)
        guard count > 0 else { return [] }

        let beatTimes = generateBeatTimes(
            duration: durationSeconds, heartRateBPM: heartRateBPM, hrvMS: hrvMS, rng: &rng
        )

        var signal = [Double](repeating: 0, count: count)
        for i in 0..<count {
            let t = Double(i) / sampleRate
            var v = 0.0
            for beat in beatTimes where abs(t - beat) < 0.5 {
                v += ecgComplex(t - beat)
            }
            v += baselineWander * sin(2 * .pi * 0.15 * t)        // baseline wander
            if noise > 0 { v += noise * rng.nextGaussian() }
            signal[i] = v
        }
        return signal
    }

    // MARK: - Beat morphology

    /// One PPG cardiac cycle: systolic upstroke + dicrotic notch.
    private static func ppgPulse(_ dt: Double) -> Double {
        guard dt >= -0.05 else { return 0 }
        let systolic = gaussian(dt, mu: 0.16, sigma: 0.05)
        let dicrotic = 0.35 * gaussian(dt, mu: 0.42, sigma: 0.06)
        return systolic + dicrotic
    }

    /// One ECG cardiac cycle as a sum of Gaussians (P, Q, R, S, T).
    private static func ecgComplex(_ dt: Double) -> Double {
        0.10 * gaussian(dt, mu: -0.20, sigma: 0.025) +   // P
        -0.15 * gaussian(dt, mu: -0.025, sigma: 0.010) + // Q
        1.00 * gaussian(dt, mu: 0.000, sigma: 0.012) +   // R
        -0.25 * gaussian(dt, mu: 0.025, sigma: 0.012) +  // S
        0.30 * gaussian(dt, mu: 0.180, sigma: 0.040)     // T
    }

    private static func gaussian(_ x: Double, mu: Double, sigma: Double) -> Double {
        exp(-((x - mu) * (x - mu)) / (2 * sigma * sigma))
    }

    // MARK: - Helpers

    private static func generateBeatTimes(
        duration: Double, heartRateBPM: Double, hrvMS: Double, rng: inout SeededGenerator
    ) -> [Double] {
        var times: [Double] = []
        let meanRR = 60.0 / max(heartRateBPM, 1)
        var t = 0.2
        while t < duration {
            times.append(t)
            let jitter = (hrvMS / 1000.0) * rng.nextGaussian()
            t += max(meanRR + jitter, 0.25)
        }
        return times
    }

    private static func injectMotion(
        into signal: inout [Double], sampleRate: Double, amplitude: Double, rng: inout SeededGenerator
    ) {
        let burstCount = max(Int(Double(signal.count) / sampleRate / 4), 1)
        for _ in 0..<burstCount {
            let center = Int.random(in: 0..<signal.count, using: &rng)
            let width = Int(sampleRate * Double.random(in: 0.2...0.6, using: &rng))
            let sign = Bool.random(using: &rng) ? 1.0 : -1.0
            for k in -width...width {
                let idx = center + k
                guard idx >= 0, idx < signal.count else { continue }
                let env = exp(-Double(k * k) / Double(2 * width * width / 4 + 1))
                signal[idx] += sign * amplitude * env
            }
        }
    }
}
