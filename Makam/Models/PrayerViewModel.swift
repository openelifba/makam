import Foundation
import Combine

@MainActor
class PrayerViewModel: ObservableObject {
    @Published var schedule: DailyPrayerSchedule?
    @Published var context: PrayerContext?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var timer: AnyCancellable?

    init() {
        startTimer()
    }

    func fetchPrayers() async {
        isLoading = true
        errorMessage = nil
        do {
            let today = try await PrayerService.fetchAndCacheToday()
            self.schedule = today
            self.refreshContext()
            self.isLoading = false
        } catch {
            self.errorMessage = error.localizedDescription
            self.isLoading = false
        }
    }

    func refreshContext() {
        guard let schedule = schedule else { return }
        self.context = PrayerCalculator.context(for: schedule)
    }

    private func startTimer() {
        // Refresh context every second for countdown precision
        timer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.refreshContext()
            }
    }
}
