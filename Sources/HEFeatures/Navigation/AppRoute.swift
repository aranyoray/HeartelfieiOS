import Foundation
import HECore

/// The four primary destinations in the bottom tab bar.
public enum AppTab: String, CaseIterable, Identifiable, Hashable, Sendable {
    case home, measure, trends, profile

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .home: return "Home"
        case .measure: return "Measure"
        case .trends: return "Trends"
        case .profile: return "Profile"
        }
    }

    public var systemImage: String {
        switch self {
        case .home: return "heart.text.square.fill"
        case .measure: return "waveform.path.ecg.rectangle.fill"
        case .trends: return "chart.xyaxis.line"
        case .profile: return "person.crop.circle.fill"
        }
    }
}

/// Value-based navigation destinations pushed onto a tab's `NavigationStack`.
/// Keeping routes as plain `Hashable` values keeps navigation testable and
/// decoupled from view construction.
public enum AppRoute: Hashable, Sendable {
    /// The capture flow for a specific modality.
    case capture(Modality)
    /// A finished reading's detail screen.
    case readingDetail(CardioReading)
    /// "What this does / doesn't mean" info for a modality.
    case modalityInfo(Modality)
    /// Insights (daily summary, trend callouts, when-to-seek-care).
    case insights
    /// Per-metric trend detail.
    case metricTrend(MetricKind)
    /// Settings sub-screens.
    case dataAndPrivacy
    case exportData
    case about
}
