import Foundation
import HECore

/// A single biquad IIR section (Direct Form I). Coefficients follow the well-known
/// RBJ "Audio EQ Cookbook" formulas.
public struct Biquad: Sendable {
    private let b0, b1, b2, a1, a2: Double

    init(b0: Double, b1: Double, b2: Double, a0: Double, a1: Double, a2: Double) {
        self.b0 = b0 / a0
        self.b1 = b1 / a0
        self.b2 = b2 / a0
        self.a1 = a1 / a0
        self.a2 = a2 / a0
    }

    /// Constant-0dB-peak bandpass section centred at `centerHz` with quality `q`.
    public static func bandpass(centerHz: Double, q: Double, sampleRate: Double) -> Biquad {
        let w0 = 2 * Double.pi * centerHz / sampleRate
        let alpha = sin(w0) / (2 * max(q, 0.0001))
        return Biquad(
            b0: alpha, b1: 0, b2: -alpha,
            a0: 1 + alpha, a1: -2 * cos(w0), a2: 1 - alpha
        )
    }

    /// Apply the section forward over a sample array.
    public func apply(_ x: [Double]) -> [Double] {
        var y = [Double](repeating: 0, count: x.count)
        var x1 = 0.0, x2 = 0.0, y1 = 0.0, y2 = 0.0
        for i in 0..<x.count {
            let xn = x[i]
            let yn = b0 * xn + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
            y[i] = yn
            x2 = x1; x1 = xn
            y2 = y1; y1 = yn
        }
        return y
    }
}

/// A configurable bandpass filter built from an RBJ biquad, with optional
/// zero-phase (forward-backward) application for accurate peak *timing*.
public struct BandpassFilter: Sendable {
    private let biquad: Biquad
    public let lowHz: Double
    public let highHz: Double
    public let sampleRate: Double

    public init(lowHz: Double, highHz: Double, sampleRate: Double) {
        self.lowHz = lowHz
        self.highHz = highHz
        self.sampleRate = sampleRate
        let center = (lowHz * highHz).squareRoot()
        let bandwidth = max(highHz - lowHz, 0.0001)
        let q = center / bandwidth
        self.biquad = Biquad.bandpass(centerHz: center, q: q, sampleRate: sampleRate)
    }

    /// Standard forward filtering (introduces phase delay).
    public func filter(_ x: [Double]) -> [Double] {
        biquad.apply(x)
    }

    /// Zero-phase forward-backward filtering (filtfilt-style). Removes the phase
    /// delay so detected peak indices line up with the true signal.
    ///
    /// The input is mean-centred and reflect-padded before filtering: raw camera
    /// channels carry a DC offset far larger than the pulse AC, and an IIR
    /// starting from zero state produces edge transients of that magnitude —
    /// enough to swamp the peak-detector threshold and the SQI amplitude check
    /// for the first/last beats. Padding absorbs the transient; the pad is
    /// trimmed from the result.
    public func filtfilt(_ x: [Double]) -> [Double] {
        guard x.count > 2 else { return x }
        let mean = x.reduce(0, +) / Double(x.count)
        let centered = x.map { $0 - mean }

        // ≈ 3 time constants of the low cutoff, bounded by the signal length.
        let pad = min(x.count - 1, max(8, Int((3.0 * sampleRate / max(lowHz, 0.0001)).rounded())))
        var padded = [Double]()
        padded.reserveCapacity(centered.count + 2 * pad)
        padded.append(contentsOf: centered[1...pad].reversed())
        padded.append(contentsOf: centered)
        padded.append(contentsOf: centered[(centered.count - 1 - pad)..<(centered.count - 1)].reversed())

        let forward = biquad.apply(padded)
        let back = Array(biquad.apply(Array(forward.reversed())).reversed())
        return Array(back[pad..<(pad + centered.count)])
    }
}

/// Recommended bandpass passband (Hz) for each modality's primary channel.
public enum FilterBand {
    /// Cardiac band for PPG/ECG (~30–210 bpm).
    public static func passband(for modality: Modality) -> (low: Double, high: Double) {
        switch modality {
        case .fingerPPG, .facialRPPG:
            return (0.7, 3.5)
        }
    }
}
