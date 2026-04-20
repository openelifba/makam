import SwiftUI

struct MainTabView: View {
    @State private var selectedTab: AppTab = .prayerTimes
    @EnvironmentObject var lang: LanguageManager

    init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(red: 0.08, green: 0.08, blue: 0.10, alpha: 1.0)

        let normal = appearance.stackedLayoutAppearance.normal
        let dimSand = UIColor(red: 0.910, green: 0.835, blue: 0.690, alpha: 0.40)
        let gold    = UIColor(red: 0.780, green: 0.620, blue: 0.340, alpha: 1.0)

        normal.iconColor = dimSand
        normal.titleTextAttributes = [.foregroundColor: dimSand]

        let selected = appearance.stackedLayoutAppearance.selected
        selected.iconColor = gold
        selected.titleTextAttributes = [.foregroundColor: gold]

        UITabBar.appearance().standardAppearance = appearance
        if #available(iOS 15, *) {
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            HabitView()
                .tabItem {
                    Image(systemName: "checklist")
                    Text(lang.str(.tabHabits))
                }
                .tag(AppTab.habit)

            ContentView()
                .tabItem {
                    Image(systemName: "moon.stars")
                    Text(lang.str(.tabPrayerTimes))
                }
                .tag(AppTab.prayerTimes)

            QiblaView()
                .tabItem {
                    Image(systemName: "location.north.line")
                    Text(lang.str(.tabQibla))
                }
                .tag(AppTab.qibla)

            ShortsView()
                .tabItem {
                    Image(systemName: "play.rectangle.on.rectangle")
                    Text("Shorts")
                }
                .tag(AppTab.shorts)

            SettingsView(selectedTab: $selectedTab)
                .tabItem {
                    Image(systemName: "gearshape")
                    Text(lang.str(.tabSettings))
                }
                .tag(AppTab.settings)
        }
        .accentColor(Makam.gold)
        .compatOnChange(of: selectedTab) { newTab in
            Analytics.logEvent(
                "tab_selected",
                metadata: ["tabName": String(describing: newTab)]
            )
        }
    }
}

enum AppTab {
    case habit, prayerTimes, qibla, shorts, settings
}
