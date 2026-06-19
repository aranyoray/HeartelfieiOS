import Foundation

/// Detects systolic (PPG) / R (ECG) peaks in a filtered, cardiac-band signal.
///
/// Uses an adaptive amplitude threshold plus a physiological refractory period so
/// it won't double-count a single beat. Works on any roughly periodic cardiac
/// waveform; tuned for clean and lightly-noisy signals.
public struct PeakDetector: Sendable {

    /// Highest plausible heart rate (bpm); sets the refractory window.
    public let maxBPM: Double
    /// Threshold as a multiple of the signal's standard deviation above its mean.
    public let thresholdSD: Double

    public init(maxBPM: Double = 220, thresholdSD: Double = 0.4) {
        self.maxBPM = maxBPM
        self.thresholdSD = thresholdSD
    }

    /// Returns the indices of detected peaks in `signal`.
    public func peakIndices(in signal: [Double], sampleRate: Double) -> [Int] {
        guard signal.count > 3, sampleRate > 0 else { return [] }

        let mean = Vector.mean(signal)
        let sd = Vector.std(signal)
        let threshold = mean + thresholdSD * sd

        // Minimum samples between peaks given the max plausible HR.
        let refractory = max(Int(sampleRate * 60.0 / maxBPM), 1)

        var peaks: [Int] = []
        var lastPeak = -refractory

        var i = 1
        while i < signal.count - 1 {
            let v = signal[i]
            let isLocalMax = v > signal[i - 1] && v >= signal[i + 1]
            if isLocalMax && v > threshold && (i - lastPeak) >= refractory {
                // Refine: pick the true local max within a small window.
                var best = i
                let windowEnd = min(i + refractory / 2, signal.count - 1)
                var j = i + 1
                while j <= windowEnd {
                    if signal[j] > signal[best] { best = j }
                    j += 1
                }
                peaks.append(best)
                lastPeak = best
                i = best + refractory
            } else {
                i += 1
            }
        }
        return peaks
    }

    /// Convert peak indices to RR (inter-beat) intervals in milliseconds.
    public func rrIntervalsMS(peakIndices: [Int], sampleRate: Double) -> [Double] {
        guard peakIndices.count > 1, sampleRate > 0 else { return [] }
        var rr: [Double] = []
        for k in 1..<peakIndices.count {
            let deltaSamples = Double(peakIndices[k] - peakIndices[k - 1])
            rr.append(deltaSamples / sampleRate * 1000.0)
        }
        return rr
    }
}
