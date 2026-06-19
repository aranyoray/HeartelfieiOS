import SwiftUI
import HECore

// MARK: - Empty state

/// A calm, centered empty state with an icon, title, supporting message, and an
/// optional primary action.
public struct EmptyStateView: View {
    private let systemImage: String
    private let title: String
    private let message: String
    private let actionTitle: String?
    private let action: (() -> Void)?

    public init(
        systemImage: String,
        title: String,
        message: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.systemImage = systemImage
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }

    public var body: some View {
        VStack(spacing: HESpacing.md) {
            Image(systemName: systemImage)
                .font(.system(size: 44, weight: .regular))
                .foregroundStyle(Color.hePrimary)
                .accessibilityHidden(true)

            VStack(spacing: HESpacing.xs) {
                Text(title)
                    .font(.heTitle)
                    .foregroundStyle(Color.heTextPrimary)
                    .multilineTextAlignment(.center)

                Text(message)
                    .font(.heBody)
                    .foregroundStyle(Color.heTextSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let actionTitle, let action {
                HEPrimaryButton(actionTitle, action: action)
                    .fixedSize()
                    .padding(.top, HESpacing.xs)
            }
        }
        .padding(HESpacing.xl)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Loading state

/// A centered, indeterminate loading state with a short message.
public struct LoadingStateView: View {
    private let message: String

    public init(message: String = "Working…") {
        self.message = message
    }

    public var body: some View {
        VStack(spacing: HESpacing.md) {
            ProgressView()
                .controlSize(.large)
                .tint(Color.hePrimary)

            Text(message)
                .font(.heCallout)
                .foregroundStyle(Color.heTextSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(HESpacing.xl)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(message)
        .accessibilityAddTraits(.updatesFrequently)
    }
}

// MARK: - Error state

/// A non-alarmist error state with an icon, message, and optional retry action.
public struct ErrorStateView: View {
    private let message: String
    private let retryTitle: String
    private let retry: (() -> Void)?

    public init(
        message: String,
        retryTitle: String = "Try Again",
        retry: (() -> Void)? = nil
    ) {
        self.message = message
        self.retryTitle = retryTitle
        self.retry = retry
    }

    public var body: some View {
        VStack(spacing: HESpacing.md) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40, weight: .regular))
                .foregroundStyle(Color.heRisk(.watch))
                .accessibilityHidden(true)

            Text(message)
                .font(.heBody)
                .foregroundStyle(Color.heTextPrimary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            if let retry {
                HESecondaryButton(retryTitle, systemImage: "arrow.clockwise", action: retry)
                    .fixedSize()
                    .padding(.top, HESpacing.xs)
            }
        }
        .padding(HESpacing.xl)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Error. \(message)")
    }
}

#Preview("State views") {
    ScrollView {
        VStack(spacing: HESpacing.xl) {
            EmptyStateView(
                systemImage: "heart.text.square",
                title: "No checks yet today",
                message: "Take a quick screening to see your cardio score and trends.",
                actionTitle: "Start a check",
                action: {}
            )

            Divider()

            LoadingStateView(message: "Analyzing your reading…")

            Divider()

            ErrorStateView(
                message: "We couldn't reach the device. Make sure it's nearby and charged.",
                retry: {}
            )
        }
        .padding()
    }
    .background(Color.heBackground)
}
