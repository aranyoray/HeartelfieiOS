import SwiftUI
import HECore

/// A tappable status chip for the Heartelfie hardware device: a connection dot +
/// state name, battery (when known), and contact status. Sized with a friendly
/// tap target.
public struct DeviceStatusChip: View {
    private let state: DeviceState

    public init(state: DeviceState) {
        self.state = state
    }

    // MARK: Derived display values

    private var connectionColor: Color {
        switch state.connection {
        case .connected:    return Color.heRisk(.normal)
        case .connecting,
             .reconnecting,
             .scanning:     return Color.heRisk(.watch)
        case .disconnected: return Color.heTextTertiary
        }
    }

    /// Shows a pulsing dot only while a transient connection state is in flight.
    private var isBusy: Bool {
        switch state.connection {
        case .connecting, .reconnecting, .scanning: return true
        default: return false
        }
    }

    private var batteryGlyph: String? {
        guard let level = state.batteryLevel else { return nil }
        switch level {
        case ..<0.15: return "battery.0percent"
        case ..<0.45: return "battery.25percent"
        case ..<0.7:  return "battery.50percent"
        case ..<0.9:  return "battery.75percent"
        default:      return "battery.100percent"
        }
    }

    private var batteryText: String? {
        guard let level = state.batteryLevel else { return nil }
        return "\(Int((level * 100).rounded()))%"
    }

    private var contactColor: Color {
        switch state.contact {
        case .good:    return Color.heRisk(.normal)
        case .poor:    return Color.heRisk(.watch)
        case .none:    return Color.heRisk(.elevated)
        case .unknown: return Color.heTextTertiary
        }
    }

    public var body: some View {
        HStack(spacing: HESpacing.sm) {
            ConnectionDot(color: connectionColor, isBusy: isBusy)

            VStack(alignment: .leading, spacing: HESpacing.xxs) {
                HStack(spacing: HESpacing.xs) {
                    Text(state.deviceName ?? state.connection.displayName)
                        .font(.heCallout.weight(.semibold))
                        .foregroundStyle(Color.heTextPrimary)
                        .lineLimit(1)

                    if state.isSimulated {
                        Text("SIM")
                            .font(.heCaption.weight(.bold))
                            .foregroundStyle(Color.heAccent)
                    }
                }

                if state.deviceName != nil {
                    Text(state.connection.displayName)
                        .font(.heCaption)
                        .foregroundStyle(Color.heTextSecondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: HESpacing.sm)

            // Contact status (only meaningful when connected).
            if state.isConnected {
                Image(systemName: state.contact.isUsable ? "hand.thumbsup.fill" : "hand.point.up.braille.fill")
                    .font(.heCaption)
                    .foregroundStyle(contactColor)
                    .accessibilityHidden(true)
            }

            // Battery.
            if let batteryGlyph, let batteryText {
                HStack(spacing: HESpacing.xxs) {
                    Image(systemName: batteryGlyph)
                        .imageScale(.medium)
                    Text(batteryText)
                        .font(.heCaption.weight(.medium))
                        .monospacedDigit()
                }
                .foregroundStyle(Color.heTextSecondary)
            }
        }
        .padding(.vertical, HESpacing.sm)
        .padding(.horizontal, HESpacing.md)
        .frame(minHeight: 44) // comfortable tap target
        .background(
            Capsule(style: .continuous)
                .fill(Color.heSurfaceElevated)
        )
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(Color.heSeparator, lineWidth: 1)
        )
        .heSubtleShadow()
        .contentShape(Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(.isButton)
    }

    private var accessibilityLabel: String {
        var parts: [String] = []
        if let name = state.deviceName { parts.append(name) }
        parts.append(state.connection.displayName)
        if state.isConnected { parts.append(state.contact.displayName) }
        if let batteryText { parts.append("battery \(batteryText)") }
        if state.isSimulated { parts.append("simulated") }
        return parts.joined(separator: ", ")
    }
}

/// A connection indicator dot with an optional gentle pulse for busy states.
private struct ConnectionDot: View {
    let color: Color
    let isBusy: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 10, height: 10)
            .overlay(
                Circle()
                    .stroke(color, lineWidth: 2)
                    .scaleEffect(pulse ? 2.0 : 1.0)
                    .opacity(pulse ? 0 : 0.6)
            )
            .onAppear {
                guard isBusy, !reduceMotion else { return }
                withAnimation(.easeOut(duration: 1.1).repeatForever(autoreverses: false)) {
                    pulse = true
                }
            }
            .accessibilityHidden(true)
    }
}

#Preview("Device status chips") {
    VStack(alignment: .leading, spacing: HESpacing.md) {
        DeviceStatusChip(
            state: DeviceState(
                connection: .connected,
                contact: .good,
                batteryLevel: 0.82,
                deviceName: "Heartelfie One"
            )
        )
        DeviceStatusChip(
            state: DeviceState(connection: .reconnecting, contact: .poor, batteryLevel: 0.2)
        )
        DeviceStatusChip(state: DeviceState(connection: .scanning))
        DeviceStatusChip(state: .disconnected)
        DeviceStatusChip(
            state: DeviceState(
                connection: .connected,
                contact: .good,
                batteryLevel: 0.55,
                deviceName: "Mock",
                isSimulated: true
            )
        )
    }
    .padding()
    .background(Color.heBackground)
}
