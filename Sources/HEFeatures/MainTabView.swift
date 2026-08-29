import SwiftUI
import HECore
import HEDesign

/// The bottom tab bar: Home · Measure · Trends · Profile. Each tab is its own
/// `NavigationStack` that resolves value-based `AppRoute` destinations.
public struct MainTabView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var selectedTab: AppTab = .home

    public init() {}

    public var body: some View {
        TabView(selection: $selectedTab) {
            ForEach(AppTab.allCases) { tab in
                NavigationStack {
                    rootView(for: tab)
                        .heContentWidthCapped()
                        .navigationDestination(for: AppRoute.self) { route in
                            destination(for: route)
                                .heContentWidthCapped()
                        }
                }
                .tabItem { Label(tab.title, systemImage: tab.systemImage) }
                .tag(tab)
            }
        }
        .onOpenURL { url in
            // Widget deep link: dailydil://check lands on the Measure tab.
            if url.scheme == "dailydil" {
                selectedTab = .measure
            }
        }
    }

    @ViewBuilder
    private func rootView(for tab: AppTab) -> some View {
        switch tab {
        case .home: HomeView()
        case .measure: MeasureHomeView()
        case .trends: TrendsView()
        case .profile: ProfileView()
        }
    }

    @ViewBuilder
    private func destination(for route: AppRoute) -> some View {
        switch route {
        case .capture(let modality):
            CaptureFlowView(modality: modality)
        case .readingDetail(let reading):
            ResultDetailView(reading: reading)
        case .modalityInfo(let modality):
            ModalityInfoView(modality: modality)
        case .insights:
            InsightsView()
        case .metricTrend(let metric):
            MetricTrendView(metric: metric)
        case .dataAndPrivacy:
            DataAndPrivacyView()
        case .exportData:
            ExportDataView()
        case .about:
            AboutView()
        }
    }
}

#Preview {
    MainTabView()
        .environment(AppEnvironment.preview())
}
