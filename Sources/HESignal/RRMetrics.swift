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
        // Reject physiologically implausible intervals (250–2000 ms ≈ 30–240 bpm),
        // keeping original indices so "successive" differences never span a
        // removed artifact (stitching non-adjacent beats biases RMSSD).
        let keptIndices = rr.indices.filter { rr[$0] >= 250 && rr[$0] <= 2000 }
        let clean = keptIndices.map { rr[$0] }
        guard clean.count >= minBeats else { return nil }

        let meanRR = Vector.mean(clean)
        guard meanRR > 0 else { return nil }

        self.heartRateBPM = 60_000.0 / meanRR

        // Sample standard deviation (n−1), the SDNN convention; population std
        // biases small windows low enough to cross the reference-range boundary.
        let sumSq = clean.reduce(0) { $0 + ($1 - meanRR) * ($1 - meanRR) }
        self.sdnnMS = (sumSq / Double(clean.count - 1)).squareRoot()

        var successiveDiffs: [Double] = []
        for k in 1..<keptIndices.count where keptIndices[k] == keptIndices[k - 1] + 1 {
            successiveDiffs.append(clean[k] - clean[k - 1])
        }
        self.rmssdMS = successiveDiffs.isEmpty ? 0 : Vector.rootMeanSquare(successiveDiffs)

        let median = Vector.median(clean)
        let deviating = clean.filter { abs($0 - median) > 0.2 * median }.count
        self.irregularityPercent = Double(deviating) / Double(clean.count) * 100.0

        self.beatCount = clean.count
    }
}
