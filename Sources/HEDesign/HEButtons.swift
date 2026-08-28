import SwiftUI
import HECore

// MARK: - Button style

/// The DailyDil primary button style: a soft, gradient-filled, pill-shaped
/// control with a gentle press response that respects Reduce Motion.
public struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled

    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.heHeadline.weight(.semibold))
            .foregroundStyle(Color(hex: "06121F"))
            .frame(maxWidth: .infinity)
            .padding(.vertical, HESpacing.md)
            .padding(.horizontal, HESpacing.lg)
            .background(
                RoundedRectangle(cornerRadius: HERadius.pill, style: .continuous)
                    .fill(Color.hePrimaryGradient)
                    .opacity(isEnabled ? 1 : 0.5)
            )
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

/// Secondary, lower-emphasis button style: tinted, bordered, pill-shaped.
public struct SecondaryButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled

    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.heHeadline.weight(.semibold))
            .foregroundStyle(Color.hePrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, HESpacing.md)
            .padding(.horizontal, HESpacing.lg)
            .background(
                RoundedRectangle(cornerRadius: HERadius.pill, style: .continuous)
                    .fill(Color.hePrimary.opacity(0.12))
            )
            .overlay(
                RoundedRectangle(cornerRadius: HERadius.pill, style: .continuous)
                    .strokeBorder(Color.hePrimary.opacity(0.30), lineWidth: 1)
            )
            .opacity(isEnabled ? 1 : 0.5)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Shared label

/// Internal label that renders an optional symbol, title, and a swap-in spinner
/// for the loading state.
private struct HEButtonLabel: View {
    let title: String
    let systemImage: String?
    let isLoading: Bool

    var body: some View {
        HStack(spacing: HESpacing.sm) {
            if isLoading {
                ProgressView()
                    .controlSize(.small)
                    .tint(.white)
            } else if let systemImage {
                Image(systemName: systemImage)
                    .imageScale(.medium)
            }
            Text(title)
        }
        // Keep the title visible but inert while loading.
        .opacity(isLoading ? 0.85 : 1)
    }
}

// MARK: - Primary button

public struct HEPrimaryButton: View {
    private let title: String
    private let systemImage: String?
    private let isLoading: Bool
    private let action: () -> Void

    public init(
        _ title: String,
        systemImage: String? = nil,
        isLoading: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.isLoading = isLoading
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HEButtonLabel(title: title, systemImage: systemImage, isLoading: isLoading)
        }
        .buttonStyle(PrimaryButtonStyle())
        .disabled(isLoading)
        .accessibilityLabel(title)
        .accessibilityValue(isLoading ? "Loading" : "")
    }
}

// MARK: - Secondary button

public struct HESecondaryButton: View {
    private let title: String
    private let systemImage: String?
    private let isLoading: Bool
    private let action: () -> Void

    public init(
        _ title: String,
        systemImage: String? = nil,
        isLoading: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.isLoading = isLoading
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: HESpacing.sm) {
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .tint(Color.hePrimary)
                } else if let systemImage {
                    Image(systemName: systemImage)
                        .imageScale(.medium)
                }
                Text(title)
            }
        }
        .buttonStyle(SecondaryButtonStyle())
        .disabled(isLoading)
        .accessibilityLabel(title)
        .accessibilityValue(isLoading ? "Loading" : "")
    }
}

#Preview("Buttons") {
    VStack(spacing: HESpacing.md) {
        HEPrimaryButton("Start today's check", systemImage: "heart.fill") {}
        HEPrimaryButton("Working", isLoading: true) {}
        HESecondaryButton("Connect device", systemImage: "sensor.tag.radiowaves.forward.fill") {}
        HEPrimaryButton("Disabled", action: {}).disabled(true)
    }
    .padding()
    .background(Color.heBackground)
}
