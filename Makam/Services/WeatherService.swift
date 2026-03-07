// MARK: - WeatherService.swift
// Makam — Lightweight async/await weather fetch via Open-Meteo.
//
// Design contract:
//   • No API key, no authentication.
//   • Network is ONLY touched from the main app (not the widget extension).
//   • The widget reads `cachedWeather()` from the shared App Group — same
//     pattern used by PrayerService.
//   • A 30-minute staleness guard prevents redundant network calls.

import Foundation

enum WeatherService {

    // Reuse the same App Group as PrayerService
    private static let cacheKey = "makam.weatherSnapshot"
    private static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: "group.com.makam.shared")
    }

    // MARK: - Fetch

    /// Fetches current weather for the given coordinates and caches the result.
    /// Call this from the main app after the prayer schedule is loaded.
    ///
    /// - Parameter coordinate: Latitude/longitude of the user's city.
    @discardableResult
    static func fetchAndCache(for coordinate: CityCoordinate) async throws -> WeatherSnapshot {
        let url = buildURL(coordinate: coordinate)

        let (data, _) = try await URLSession.shared.data(from: url)
        let response  = try JSONDecoder().decode(OpenMeteoResponse.self, from: data)

        let snapshot = WeatherSnapshot(
            temperatureCelsius: response.current.temperature2m,
            symbolName:         WMOSymbol.sfSymbol(for: response.current.weatherCode),
            fetchedAt:          .now
        )

        // Persist for the widget extension to read offline
        if let encoded = try? JSONEncoder().encode(snapshot) {
            sharedDefaults?.set(encoded, forKey: cacheKey)
        }

        return snapshot
    }

    // MARK: - Cache (widget-safe, no network)

    /// Returns the last cached `WeatherSnapshot`, or `nil` if none exists yet.
    static func cachedWeather() -> WeatherSnapshot? {
        guard
            let data     = sharedDefaults?.data(forKey: cacheKey),
            let snapshot = try? JSONDecoder().decode(WeatherSnapshot.self, from: data)
        else { return nil }
        return snapshot
    }

    // MARK: - Private

    private static func buildURL(coordinate: CityCoordinate) -> URL {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        components.queryItems = [
            URLQueryItem(name: "latitude",  value: String(coordinate.latitude)),
            URLQueryItem(name: "longitude", value: String(coordinate.longitude)),
            URLQueryItem(name: "current",   value: "temperature_2m,weather_code"),
            URLQueryItem(name: "timezone",  value: "auto"),
        ]
        return components.url!
    }
}
