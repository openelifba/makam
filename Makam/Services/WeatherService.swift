// MARK: - WeatherService.swift
// Makam — Lightweight async/await weather fetching via Open-Meteo API.
//
// Open-Meteo is free and requires no API key.
// Endpoint: GET https://api.open-meteo.com/v1/forecast
//
// Requested fields:
//   current: temperature_2m, apparent_temperature, relative_humidity_2m,
//            windspeed_10m, weather_code
//   daily:   sunrise, sunset (for prayer time correlation in the detail sheet)

import Foundation

// MARK: - Service

enum WeatherService {

    private static let baseURL = "https://api.open-meteo.com/v1/forecast"

    // MARK: - Fetch

    static func fetchWeather(latitude: Double, longitude: Double) async throws -> WeatherSnapshot {
        guard let url = buildURL(latitude: latitude, longitude: longitude) else {
            throw WeatherServiceError.invalidURL
        }

        let data: Data
        do {
            let (responseData, _) = try await URLSession.shared.data(from: url)
            data = responseData
        } catch {
            throw WeatherServiceError.network(error)
        }

        do {
            let response = try JSONDecoder().decode(OpenMeteoResponse.self, from: data)
            return toSnapshot(response)
        } catch {
            throw WeatherServiceError.decoding(error)
        }
    }

    // MARK: - Private Helpers

    private static func buildURL(latitude: Double, longitude: Double) -> URL? {
        var components = URLComponents(string: baseURL)
        components?.queryItems = [
            URLQueryItem(name: "latitude",      value: String(format: "%.4f", latitude)),
            URLQueryItem(name: "longitude",     value: String(format: "%.4f", longitude)),
            URLQueryItem(name: "current",       value: "temperature_2m,apparent_temperature,relative_humidity_2m,windspeed_10m,weather_code"),
            URLQueryItem(name: "daily",         value: "sunrise,sunset"),
            URLQueryItem(name: "timezone",      value: "auto"),
            URLQueryItem(name: "forecast_days", value: "1")
        ]
        return components?.url
    }

    private static func toSnapshot(_ response: OpenMeteoResponse) -> WeatherSnapshot {
        let c = response.current
        let sunrise = parseDateTime(response.daily.sunrise.first ?? "")
        let sunset  = parseDateTime(response.daily.sunset.first  ?? "")
        return WeatherSnapshot(
            sfSymbol:       sfSymbol(for: c.weatherCode),
            temperature:    Int(c.temperature2m.rounded()),
            feelsLike:      Int(c.apparentTemperature.rounded()),
            humidity:       c.relativeHumidity2m,
            windSpeed:      Int(c.windspeed10m.rounded()),
            shortCondition: condition(for: c.weatherCode),
            sunrise:        sunrise ?? Date(),
            sunset:         sunset  ?? Date()
        )
    }

    /// Open-Meteo returns daily sunrise/sunset as "2026-03-09T06:30" (no timezone offset in string,
    /// but the API is queried with timezone=auto so values are already in local time).
    private static func parseDateTime(_ string: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.date(from: string)
    }

    // MARK: - WMO Weather Code → SF Symbol

    /// Maps WMO Weather Interpretation Codes to the most appropriate SF Symbol.
    /// Reference: https://open-meteo.com/en/docs — WMO codes table.
    private static func sfSymbol(for code: Int) -> String {
        switch code {
        case 0:           return "sun.max.fill"
        case 1:           return "sun.max.fill"
        case 2:           return "cloud.sun.fill"
        case 3:           return "cloud.fill"
        case 45, 48:      return "cloud.fog.fill"
        case 51, 53, 55:  return "cloud.drizzle.fill"
        case 56, 57:      return "cloud.sleet.fill"
        case 61, 63, 65:  return "cloud.rain.fill"
        case 66, 67:      return "cloud.sleet.fill"
        case 71, 73, 75:  return "cloud.snow.fill"
        case 77:          return "cloud.snow.fill"
        case 80, 81, 82:  return "cloud.heavyrain.fill"
        case 85, 86:      return "cloud.snow.fill"
        case 95:          return "cloud.bolt.rain.fill"
        case 96, 99:      return "cloud.bolt.rain.fill"
        default:          return "cloud.fill"
        }
    }

    // MARK: - WMO Weather Code → Turkish Condition Label (≤ 12 chars)

    private static func condition(for code: Int) -> String {
        switch code {
        case 0:           return "Açık"
        case 1:           return "Az Bulutlu"
        case 2:           return "Parçalı"
        case 3:           return "Bulutlu"
        case 45, 48:      return "Sisli"
        case 51, 53, 55:  return "Çiseleme"
        case 56, 57:      return "Dondurucu"
        case 61, 63, 65:  return "Yağmurlu"
        case 66, 67:      return "Buzlu Yağmur"
        case 71, 73, 75:  return "Karlı"
        case 77:          return "Kar Tanesi"
        case 80, 81, 82:  return "Sağanak"
        case 85, 86:      return "Kar Sağanağı"
        case 95:          return "Gök Gürültülü"
        case 96, 99:      return "Dolu"
        default:          return "Değişken"
        }
    }
}

// MARK: - Errors

enum WeatherServiceError: LocalizedError {
    case invalidURL
    case network(Error)
    case decoding(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:       return "Invalid weather API URL."
        case .network(let e):   return "Network error: \(e.localizedDescription)"
        case .decoding(let e):  return "Could not parse weather data: \(e.localizedDescription)"
        }
    }
}
