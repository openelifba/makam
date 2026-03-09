import Foundation
import Combine

@MainActor
class PrayerViewModel: ObservableObject {
    @Published var schedule: DailyPrayerSchedule?
    @Published var context: PrayerContext?
    @Published var isLoading = false
    @Published var errorMessage: String?

    // Weather — fetched opportunistically after prayer data loads.
    // Failures are silent: the app's primary function is unaffected.
    @Published var weatherState: WeatherState = .idle

    private var timer: AnyCancellable?
    private let city: DiyanetCity = .ankara

    init() {
        startTimer()
    }

    func fetchPrayers() async {
        isLoading = true
        errorMessage = nil
        do {
            let today = try await PrayerService.fetchAndCacheToday(for: city)
            self.schedule = today
            self.refreshContext()
            self.isLoading = false
            // Weather is secondary — fetch after prayer data succeeds.
            await fetchWeather()
        } catch {
            self.errorMessage = error.localizedDescription
            self.isLoading = false
        }
    }

    func fetchWeather() async {
        // Keep displaying stale data while refreshing in the background.
        switch weatherState {
        case .loaded: break
        default:      weatherState = .loading
        }

        do {
            let snapshot = try await WeatherService.fetchWeather(
                latitude:  city.latitude,
                longitude: city.longitude
            )
            weatherState = .loaded(snapshot)
        } catch {
            // Only move to .failed if we have no data to show.
            if case .loading = weatherState {
                weatherState = .failed
            }
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
