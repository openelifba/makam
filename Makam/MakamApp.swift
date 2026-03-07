import SwiftUI

@main
struct MakamApp: App {
    @StateObject private var viewModel = PrayerViewModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
                .task {
                    await viewModel.fetchPrayers()
                }
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .active {
                Task {
                    await viewModel.fetchPrayers()
                }
            }
        }
    }
}


