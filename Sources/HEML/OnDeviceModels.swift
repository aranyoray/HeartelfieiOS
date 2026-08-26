import Foundation
import HECore

#if canImport(CoreML)
import CoreML
#endif

/// On-device inference helpers that run entirely locally (no network, no
/// attribution obligations). `screenRhythm` is an optional CoreML rhythm screen
/// for phone `.fingerPPG` that falls back to a transparent heuristic when no
/// model ships.
///
/// Everything here is `Sendable` and free of mutable shared state, so it is safe
/// to call from any actor / task.
///
/// Provenance for these results is `Provenance.onDeviceCoreML`.
public final class OnDeviceModels: Sendable {

    public init() {}

    // MARK: - Rhythm screen (phone, CoreML with heuristic fallback)

    /// Screen a PPG/ECG-like waveform for rhythm irregularity.
    ///
    /// Loads a bundled CoreML model if one is present (see the integration note
    /// below). Returns `nil` when no model ships: the DSP stage's own
    /// `rhythmIrregularity` metric is strictly better than the peak-interval
    /// heuristic below (which measures RR coefficient-of-variation — a different
    /// unit than the DSP metric's reference range — and caps confidence at 0.7),
    /// so a nil here must leave the DSP result untouched rather than replace it.
    ///
    /// - Returns: estimated irregularity percentage (0...100) and a `Confidence`,
    ///   or `nil` when no trained model is available.
    public func screenRhythm(samples: [Double], sampleRate: Double) -> (irregularityPercent: Double, confidence: Confidence)? {
        #if canImport(CoreML)
        if let model = Self.loadedRhythmModel,
           let result = Self.runRhythmModel(model, samples: samples, sampleRate: sampleRate) {
            return result
        }
        #endif
        return nil
    }

    /// Kept only as a reference implementation and for unit tests; not used in
    /// the production inference path (see `screenRhythm`).

    /// Transparent fallback: estimate irregularity from the coefficient of
    /// variation of inter-peak intervals. Deliberately simple and clearly a
    /// heuristic, not a trained model — confidence is capped accordingly.
    static func heuristicRhythm(samples: [Double], sampleRate: Double) -> (irregularityPercent: Double, confidence: Confidence) {
        let peaks = simplePeakIndices(samples, sampleRate: sampleRate)
        guard peaks.count >= 3 else {
            return (0, Confidence(0.2))
        }
        var intervals: [Double] = []
        intervals.reserveCapacity(peaks.count - 1)
        for i in 1..<peaks.count {
            intervals.append(Double(peaks[i] - peaks[i - 1]) / sampleRate)
        }
        let mean = intervals.reduce(0, +) / Double(intervals.count)
        guard mean > 0 else { return (0, Confidence(0.2)) }
        let variance = intervals.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(intervals.count)
        let cv = variance.squareRoot() / mean
        // Map coefficient of variation → percent, clamped to a sane band.
        let irregularity = min(max(cv * 100.0, 0), 100)
        // Heuristic confidence grows with beat count, capped below "high".
        let beatFactor = min(Double(peaks.count) / 12.0, 1.0)
        let confidence = Confidence(0.4 + 0.3 * beatFactor)
        return (irregularity, confidence)
    }

    /// Minimal positive-going peak picker with a refractory window. Shared by the
    /// heuristic so we don't depend on HESignal internals here.
    static func simplePeakIndices(_ x: [Double], sampleRate: Double) -> [Int] {
        guard x.count > 3 else { return [] }
        let mean = x.reduce(0, +) / Double(x.count)
        let variance = x.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(x.count)
        let threshold = mean + 0.5 * variance.squareRoot()
        let refractory = max(Int(sampleRate * 0.3), 1)   // ≥300 ms between beats
        var peaks: [Int] = []
        var i = 1
        while i < x.count - 1 {
            if x[i] > threshold, x[i] >= x[i - 1], x[i] > x[i + 1] {
                if let last = peaks.last, i - last < refractory {
                    if x[i] > x[last] { peaks[peaks.count - 1] = i }
                } else {
                    peaks.append(i)
                }
            }
            i += 1
        }
        return peaks
    }

    // MARK: - Drop real weights here
    //
    // To ship a real on-device rhythm screen:
    //   1. Add `HeartelfieRhythm.mlpackage` (or `.mlmodel`) to the HEML target's
    //      resources (declare `resources: [.process("Models")]` in Package.swift
    //      for this target, or bundle it in the app and pass the URL in).
    //   2. Xcode auto-compiles `.mlmodel` → `.mlmodelc` and generates a Swift
    //      class; for `.mlpackage` / runtime loading, compile with
    //      `MLModel.compileModel(at:)` once and cache the compiled URL.
    //   3. Load via `MLModel(contentsOf: compiledURL, configuration:)` and run with
    //      a typed `MLFeatureProvider` (e.g. an `MLMultiArray` of the windowed,
    //      resampled waveform). Map the model's output to (irregularity%, conf).
    //
    // Until real weights ship, `loadedRhythmModel` is `nil` and `screenRhythm`
    // uses the heuristic above, so the module always builds and runs.

    #if canImport(CoreML)
    /// Anchor type used only to resolve this module's resource bundle via
    /// `Bundle(for:)`. Has no instances and holds no state.
    private final class ModelBundleAnchor {}

    /// Lazily-loaded CoreML rhythm model, or `nil` when no weights are bundled.
    /// Computed (not stored) to keep `OnDeviceModels` immutable & `Sendable`.
    static var loadedRhythmModel: MLModel? {
        // TODO: Replace "HeartelfieRhythm" with the real compiled model resource.
        // We resolve the bundle via a class anchor (`Bundle(for:)`) rather than
        // `Bundle.module`, because `Bundle.module` is only synthesised when the
        // SwiftPM target declares `resources:` — which HEML does not yet. Once you
        // add a resources rule for the model, switch this to `Bundle.module`.
        // Returns nil today (no weights bundled) → heuristic fallback.
        guard let url = Bundle(for: ModelBundleAnchor.self)
            .url(forResource: "HeartelfieRhythm", withExtension: "mlmodelc") else {
            return nil
        }
        let config = MLModelConfiguration()
        config.computeUnits = .all
        return try? MLModel(contentsOf: url, configuration: config)
    }

    /// Run the bundled model. Returns `nil` if the I/O shape doesn't match (so the
    /// caller falls back to the heuristic). Wiring is a placeholder until a real
    /// model + feature contract exists.
    static func runRhythmModel(_ model: MLModel, samples: [Double], sampleRate: Double) -> (irregularityPercent: Double, confidence: Confidence)? {
        // TODO: Build the model's real input. Example skeleton for a 1×N float input
        // named "waveform" producing "irregularity" and "confidence" outputs:
        //
        //   guard let array = try? MLMultiArray(shape: [NSNumber(value: samples.count)],
        //                                       dataType: .double) else { return nil }
        //   for (i, v) in samples.enumerated() { array[i] = NSNumber(value: v) }
        //   let input = try? MLDictionaryFeatureProvider(dictionary: ["waveform": array])
        //   guard let input, let out = try? model.prediction(from: input) else { return nil }
        //   let irr = out.featureValue(for: "irregularity")?.doubleValue ?? 0
        //   let conf = out.featureValue(for: "confidence")?.doubleValue ?? 0.5
        //   return (min(max(irr, 0), 100), Confidence(conf))
        //
        // No real model ships, so return nil → heuristic fallback.
        _ = model
        return nil
    }
    #endif
}
