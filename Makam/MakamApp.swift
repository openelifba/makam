import SwiftUI
import SwiftData

@main
struct MakamApp: App {
    @StateObject private var viewModel = PrayerViewModel()
    @StateObject private var languageManager = LanguageManager()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(viewModel)
                .environmentObject(languageManager)
                .task {
                    // Sync language into view model so notifications use the right locale.
                    viewModel.language = languageManager.current
                    await viewModel.fetchPrayers()
                }
                .onChange(of: languageManager.current) { _, newLanguage in
                    viewModel.language = newLanguage
                    // Reschedule notifications in the new language.
                    if let schedule = viewModel.schedule {
                        NotificationService.scheduleNotifications(for: schedule, language: newLanguage)
                    }
                }
        }
        .modelContainer(for: HabitTask.self)
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


