import Foundation
#if canImport(Accelerate)
import Accelerate
#endif

/// Low-level vector math used across the DSP layer. Uses Accelerate/vDSP on Apple
/// platforms and falls back to portable scalar loops elsewhere so the logic stays
/// testable on any host.
enum Vector {

    static func mean(_ x: [Double]) -> Double {
        guard !x.isEmpty else { return 0 }
        #if canImport(Accelerate)
        var result = 0.0
        vDSP_meanvD(x, 1, &result, vDSP_Length(x.count))
        return result
        #else
        return x.reduce(0, +) / Double(x.count)
        #endif
    }

    static func sum(_ x: [Double]) -> Double {
        #if canImport(Accelerate)
        var result = 0.0
        vDSP_sveD(x, 1, &result, vDSP_Length(x.count))
        return result
        #else
        return x.reduce(0, +)
        #endif
    }

    /// Population standard deviation.
    static func std(_ x: [Double]) -> Double {
        guard x.count > 1 else { return 0 }
        let m = mean(x)
        let centered = subtract(x, m)
        let sumSq = dot(centered, centered)
        return (sumSq / Double(x.count)).squareRoot()
    }

    static func variance(_ x: [Double]) -> Double {
        guard x.count > 1 else { return 0 }
        let m = mean(x)
        let centered = subtract(x, m)
        return dot(centered, centered) / Double(x.count)
    }

    /// Element-wise subtraction of a scalar (implemented as add of the negation).
    static func subtract(_ x: [Double], _ scalar: Double) -> [Double] {
        #if canImport(Accelerate)
        var s = -scalar
        var out = [Double](repeating: 0, count: x.count)
        vDSP_vsaddD(x, 1, &s, &out, 1, vDSP_Length(x.count))
        return out
        #else
        return x.map { $0 - scalar }
        #endif
    }

    /// Element-wise multiply by a scalar.
    static func multiply(_ x: [Double], by scalar: Double) -> [Double] {
        #if canImport(Accelerate)
        var s = scalar
        var out = [Double](repeating: 0, count: x.count)
        vDSP_vsmulD(x, 1, &s, &out, 1, vDSP_Length(x.count))
        return out
        #else
        return x.map { $0 * scalar }
        #endif
    }

    static func dot(_ a: [Double], _ b: [Double]) -> Double {
        let n = min(a.count, b.count)
        guard n > 0 else { return 0 }
        #if canImport(Accelerate)
        var result = 0.0
        vDSP_dotprD(a, 1, b, 1, &result, vDSP_Length(n))
        return result
        #else
        var acc = 0.0
        for i in 0..<n { acc += a[i] * b[i] }
        return acc
        #endif
    }

    static func maxValue(_ x: [Double]) -> Double {
        #if canImport(Accelerate)
        var result = 0.0
        vDSP_maxvD(x, 1, &result, vDSP_Length(x.count))
        return result
        #else
        return x.max() ?? 0
        #endif
    }

    static func minValue(_ x: [Double]) -> Double {
        #if canImport(Accelerate)
        var result = 0.0
        vDSP_minvD(x, 1, &result, vDSP_Length(x.count))
        return result
        #else
        return x.min() ?? 0
        #endif
    }

    /// Z-score normalisation: `(x - mean) / std`. Returns zeros if std is ~0.
    static func zscore(_ x: [Double]) -> [Double] {
        let s = std(x)
        guard s > 1e-9 else { return [Double](repeating: 0, count: x.count) }
        let centered = subtract(x, mean(x))
        return multiply(centered, by: 1.0 / s)
    }

    /// First difference: `x[i+1] - x[i]`.
    static func diff(_ x: [Double]) -> [Double] {
        guard x.count > 1 else { return [] }
        var out = [Double](repeating: 0, count: x.count - 1)
        for i in 0..<(x.count - 1) { out[i] = x[i + 1] - x[i] }
        return out
    }

    static func rootMeanSquare(_ x: [Double]) -> Double {
        guard !x.isEmpty else { return 0 }
        return (dot(x, x) / Double(x.count)).squareRoot()
    }

    static func median(_ x: [Double]) -> Double {
        guard !x.isEmpty else { return 0 }
        let sorted = x.sorted()
        let mid = sorted.count / 2
        if sorted.count % 2 == 0 {
            return (sorted[mid - 1] + sorted[mid]) / 2
        }
        return sorted[mid]
    }
}
