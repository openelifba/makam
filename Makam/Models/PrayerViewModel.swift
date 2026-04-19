import Foundation
import Combine
import CoreLocation

private enum PrayerViewModelError: LocalizedError {
    case noLocationSelected
    case geocodingFailed

    var errorDescription: String? {
        switch self {
        case .noLocationSelected: return "Şehir seçilmedi. Lütfen ayarlardan şehrinizi seçin."
        case .geocodingFailed:    return "Seçilen şehrin koordinatları alınamadı."
        }
    }
}

@MainActor
class PrayerViewModel: ObservableObject {
    @Published var schedule: DailyPrayerSchedule?
    @Published var context: PrayerContext?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var locationName: String = SettingsViewModel.savedLocationLabel()

    // Weather — fetched opportunistically after prayer data loads.
    // Failures are silent: the app's primary function is unaffected.
    @Published var weatherState: WeatherState = .idle

    private var timer: AnyCancellable?

    // The language is injected after init so the view model can pass it to
    // NotificationService. Defaults to system language, updated by LanguageManager.
    var language: AppLanguage = .english

    init() {
        startTimer()
    }

    func fetchPrayers() async {
        isLoading = true
        errorMessage = nil

        let districtId = UserDefaults.standard.savedDistrictId
        do {
            let today: DailyPrayerSchedule

            if let districtId {
                let vakit = try await EzanVaktiService.fetchTodayPrayerTimes(districtId: districtId)
                guard let schedule = EzanVaktiService.toDailySchedule(from: vakit) else {
                    throw EzanVaktiServiceError.noDataForToday
                }
                today = schedule
            } else {
                throw PrayerViewModelError.noLocationSelected
            }

            self.schedule = today
            self.locationName = SettingsViewModel.savedLocationLabel()
            self.refreshContext()
            self.isLoading = false
            Analytics.logEvent(
                "prayer_times_fetched",
                metadata: ["success": "true", "districtId": districtId ?? ""]
            )
            // Schedule azan notifications for today's prayers.
            NotificationService.scheduleNotifications(for: today, language: language)
            // Weather is secondary — fetch after prayer data succeeds.
            await fetchWeather()
        } catch {
            self.errorMessage = error.localizedDescription
            self.isLoading = false
            Analytics.logEvent(
                "prayer_times_fetched",
                metadata: ["success": "false", "districtId": districtId ?? ""]
            )
        }
    }

    func fetchWeather() async {
        // Keep displaying stale data while refreshing in the background.
        switch weatherState {
        case .loaded: break
        default:      weatherState = .loading
        }

        do {
            let (lat, lon) = try await resolvedCoordinates()
            let snapshot = try await WeatherService.fetchWeather(latitude: lat, longitude: lon)
            weatherState = .loaded(snapshot)
        } catch {
            // Only move to .failed if we have no data to show.
            if case .loading = weatherState {
                weatherState = .failed
            }
        }
    }

    /// Geocodes the saved district/state/country names to coordinates.
    /// Throws if no location is saved or geocoding fails.
    private func resolvedCoordinates() async throws -> (Double, Double) {
        let parts = [UserDefaults.standard.savedDistrictName,
                     UserDefaults.standard.savedStateName,
                     UserDefaults.standard.savedCountryName]
            .compactMap { $0 }.filter { !$0.isEmpty }
        guard !parts.isEmpty else { throw PrayerViewModelError.noLocationSelected }
        let query = parts.joined(separator: ", ")
        return try await withCheckedThrowingContinuation { continuation in
            CLGeocoder().geocodeAddressString(query) { placemarks, _ in
                if let coord = placemarks?.first?.location?.coordinate {
                    continuation.resume(returning: (coord.latitude, coord.longitude))
                } else {
                    continuation.resume(throwing: PrayerViewModelError.geocodingFailed)
                }
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
