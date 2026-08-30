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
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            HabitView()
                .tabItem { Label(lang.str(.tabHabits), systemImage: "checklist") }
                .tag(AppTab.habit)

            ContentView()
                .tabItem { Label(lang.str(.tabPrayerTimes), systemImage: "moon.stars") }
                .tag(AppTab.prayerTimes)

            QiblaView()
                .tabItem { Label(lang.str(.tabQibla), systemImage: "location.north.line") }
                .tag(AppTab.qibla)

            QuranView()
                .tabItem { Label(lang.str(.tabQuran), systemImage: "book.pages") }
                .tag(AppTab.quran)

            ShortsView()
                .tabItem { Label("Shorts", systemImage: "play.rectangle.on.rectangle") }
                .tag(AppTab.shorts)

            SettingsView(selectedTab: $selectedTab)
                .tabItem { Label(lang.str(.tabSettings), systemImage: "gearshape") }
                .tag(AppTab.settings)
        }
        .tint(Makam.gold)
        .onChange(of: selectedTab) { _, newTab in
            Analytics.logEvent(
                "tab_selected",
                metadata: ["tabName": String(describing: newTab)]
            )
        }
    }
}

enum AppTab {
    case habit, prayerTimes, qibla, quran, shorts, settings
}
