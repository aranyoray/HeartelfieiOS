import SwiftUI
import HECore

/// The standard Heartelfie surface: a rounded, softly elevated card with
/// generous padding. Wraps arbitrary content.
public struct HECard<Content: View>: View {
    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        content
            .padding(HESpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: HERadius.lg, style: .continuous)
                    .fill(Color.heSurface)
            )
            .heCardShadow()
    }
}

/// A consistent section header used above cards and lists. Optional subtitle and
/// leading SF Symbol.
public struct HESectionHeader: View {
    private let title: String
    private let subtitle: String?
    private let systemImage: String?

    public init(title: String, subtitle: String? = nil, systemImage: String? = nil) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
    }

    public var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: HESpacing.sm) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.heHeadline)
                    .foregroundStyle(Color.hePrimary)
                    .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: HESpacing.xxs) {
                Text(title)
                    .font(.heTitle)
                    .foregroundStyle(Color.heTextPrimary)

                if let subtitle {
                    Text(subtitle)
                        .font(.heCallout)
                        .foregroundStyle(Color.heTextSecondary)
                }
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

#Preview("Card + section header") {
    ScrollView {
        VStack(alignment: .leading, spacing: HESpacing.lg) {
            HESectionHeader(
                title: "Today",
                subtitle: "Your latest checks",
                systemImage: "calendar"
            )

            HECard {
                VStack(alignment: .leading, spacing: HESpacing.sm) {
                    Text("Resting heart rate")
                        .font(.heHeadline)
                        .foregroundStyle(Color.heTextPrimary)
                    Text("72 bpm")
                        .font(.heMetricNumeralCompact)
                        .foregroundStyle(Color.heTextPrimary)
                    RiskBadge(.normal)
                }
            }
        }
        .padding()
    }
    .background(Color.heBackground)
}
