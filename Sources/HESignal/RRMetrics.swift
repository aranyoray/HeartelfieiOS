import Foundation

/// Heart-rate and heart-rate-variability features derived from RR intervals.
public struct RRMetrics: Sendable, Hashable {
    /// Mean heart rate in beats per minute.
    public let heartRateBPM: Double
    /// SDNN — standard deviation of RR intervals (ms).
    public let sdnnMS: Double
    /// RMSSD — root mean square of successive RR differences (ms).
    public let rmssdMS: Double
    /// Fraction of beats whose RR deviates notably from the median, as a percent.
    /// A coarse, screening-grade "rhythm irregularity" indicator.
    public let irregularityPercent: Double
    /// Number of usable RR intervals the features were computed from.
    public let beatCount: Int

    /// Compute features from RR intervals (ms). Returns `nil` if there are too few
    /// beats to be meaningful.
    public init?(rrIntervalsMS rr: [Double], minBeats: Int = 4) {
        // Reject physiologically implausible intervals (250–2000 ms ≈ 30–240 bpm).
        let clean = rr.filter { $0 >= 250 && $0 <= 2000 }
        guard clean.count >= minBeats else { return nil }

        let meanRR = Vector.mean(clean)
        guard meanRR > 0 else { return nil }

        self.heartRateBPM = 60_000.0 / meanRR
        self.sdnnMS = Vector.std(clean)

        let successiveDiffs = Vector.diff(clean)
        self.rmssdMS = successiveDiffs.isEmpty ? 0 : Vector.rootMeanSquare(successiveDiffs)

        let median = Vector.median(clean)
        let deviating = clean.filter { abs($0 - median) > 0.2 * median }.count
        self.irregularityPercent = Double(deviating) / Double(clean.count) * 100.0

        self.beatCount = clean.count
    }
}
