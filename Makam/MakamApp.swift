import SwiftUI
import SwiftData

@main
struct MakamApp: App {
    @StateObject private var viewModel = PrayerViewModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(viewModel)
                .task {
                    await viewModel.fetchPrayers()
                }
        }
        .modelContainer(for: HabitTask.self)
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .active {
                Task {
                    await viewModel.fetchPrayers()
                }
            }
        }
    }
}


