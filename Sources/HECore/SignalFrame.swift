import Foundation

/// A single physiological channel of raw signal.
public enum SignalChannel: String, Codable, Sendable, CaseIterable, Hashable {
    case red, green, blue        // camera PPG color planes
    case infrared, infrared2     // device multi-wavelength
    case ecg                     // device electrodes
    case bioImpedance            // device BioZ
    case audio                   // microphone PCG
    case accelMagnitude          // motion SCG
    case gyroMagnitude           // motion gyrocardiography
}

/// A single timestamped sample on one channel.
public struct SignalSample: Sendable, Hashable, Codable {
    public let timestamp: TimeInterval
    public let value: Double
    public let channel: SignalChannel

    public init(timestamp: TimeInterval, value: Double, channel: SignalChannel) {
        self.timestamp = timestamp
        self.value = value
        self.channel = channel
    }
}

/// One streamed acquisition frame: the set of per-channel samples captured at a
/// single instant. Multi-wavelength device sources populate several channels per
/// frame; phone PPG typically populates the color planes it reads.
///
/// `CardioSensor.start()` yields a stream of these frames.
public struct SignalFrame: Sendable, Hashable, Codable {
    public let timestamp: TimeInterval
    public let samples: [SignalSample]

    public init(timestamp: TimeInterval, samples: [SignalSample]) {
        self.timestamp = timestamp
        self.samples = samples
    }

    /// Convenience initializer for a single-channel frame.
    public init(timestamp: TimeInterval, value: Double, channel: SignalChannel) {
        self.init(timestamp: timestamp, samples: [SignalSample(timestamp: timestamp, value: value, channel: channel)])
    }

    /// The first sample's value — convenient for single-channel streams.
    public var primaryValue: Double { samples.first?.value ?? 0 }

    /// Fetch the value for a specific channel, if present in this frame.
    public func value(for channel: SignalChannel) -> Double? {
        samples.first(where: { $0.channel == channel })?.value
    }
}
