import SwiftUI
import Statsig

@main
struct MakamApp: App {
    @StateObject private var viewModel = PrayerViewModel()
    @StateObject private var languageManager = LanguageManager()
    @StateObject private var habitViewModel = HabitViewModel()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let userId: String
        if let cached = AuthManager.cachedDeviceId() {
            userId = cached
        } else {
            userId = UUID().uuidString
            UserDefaults.standard.set(userId, forKey: AuthManager.deviceIdKey)
        }
        Statsig.start(
            sdkKey: "client-Saz0qNAZ1EvptEcQrNHAgtJtRuF3yofu6wdwQM4rJaZ",
            user: StatsigUser(userID: userId),
            options: StatsigOptions()
        ) { _ in }
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(viewModel)
                .environmentObject(languageManager)
                .environmentObject(habitViewModel)
                .task {
                    viewModel.language = languageManager.current
                    SettingsViewModel.setDefaultLocationIfNeeded()
                    await viewModel.fetchPrayers()
                }
                .onChange(of: languageManager.current) { _, newLanguage in
                    viewModel.language = newLanguage
                    if let schedule = viewModel.schedule {
                        NotificationService.scheduleNotifications(for: schedule, language: newLanguage)
                    }
                }
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .active {
                Task {
                    viewModel.language = languageManager.current
                    await viewModel.fetchPrayers()
                }
            }
        }
    }
}
