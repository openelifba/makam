import Foundation
import Combine

@MainActor
class PrayerViewModel: ObservableObject {
    @Published var schedule: DailyPrayerSchedule?
    @Published var context: PrayerContext?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var locationName: String = SettingsViewModel.savedLocationLabel()

    private var timer: AnyCancellable?

    init() {
        startTimer()
    }

    func fetchPrayers() async {
        isLoading = true
        errorMessage = nil

        do {
            let today: DailyPrayerSchedule

            if let districtId = UserDefaults.standard.savedDistrictId {
                // Fetch from Imsakiyem API using the saved district
                let entries = try await ImsakiyemService.fetchDailyPrayerTimes(districtId: districtId)
                guard let schedule = try ImsakiyemService.toDailySchedule(from: entries) else {
                    throw ImsakiyemServiceError.noDataForToday
                }
                today = schedule
            } else {
                // Fall back to Aladhan with default city (Ankara) if no district is saved yet
                today = try await PrayerService.fetchAndCacheToday()
            }

            self.schedule = today
            self.locationName = SettingsViewModel.savedLocationLabel()
            self.refreshContext()
        } catch {
            self.errorMessage = error.localizedDescription
        }

        self.isLoading = false
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
