import SwiftUI

struct MainTabView: View {
    @State private var selectedTab: AppTab = .prayerTimes

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
                .tabItem { Label("Alışkanlık", systemImage: "checklist") }
                .tag(AppTab.habit)

            ContentView()
                .tabItem { Label("Namaz Vakitleri", systemImage: "moon.stars") }
                .tag(AppTab.prayerTimes)

            QiblaView()
                .tabItem { Label("Kıble", systemImage: "location.north.line") }
                .tag(AppTab.qibla)

            SettingsView(selectedTab: $selectedTab)
                .tabItem { Label("Ayarlar", systemImage: "gearshape") }
                .tag(AppTab.settings)
        }
        .tint(Makam.gold)
    }
}

enum AppTab {
    case habit, prayerTimes, qibla, settings
}
