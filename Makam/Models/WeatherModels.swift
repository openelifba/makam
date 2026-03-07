// MARK: - WeatherModels.swift
// Makam — Minimal weather data types. Weather is ambient context, not a feature.
//
// Source: Open-Meteo API (https://open-meteo.com) — free, no API key.
// WMO Weather Interpretation Code 4677 → SF Symbol mapping kept here so the
// service layer stays purely network-focused.

import Foundation

// MARK: - Raw API Response

/// Matches the Open-Meteo `/v1/forecast` response shape.
/// Only `current` block is decoded — we don't need hourly/daily for ambient display.
struct OpenMeteoResponse: Codable {
    let current: CurrentWeather

    struct CurrentWeather: Codable {
        let temperature2m: Double   // °C
        let weatherCode:   Int      // WMO 4677 code

        enum CodingKeys: String, CodingKey {
            case temperature2m = "temperature_2m"
            case weatherCode   = "weather_code"
        }
    }
}

// MARK: - Domain Snapshot

/// Everything the widget needs to render a weather chip. Codable so it can be
/// written to the shared App Group cache and read without a network call.
struct WeatherSnapshot: Codable, Equatable {
    let temperatureCelsius: Double   // e.g. 12.4
    let symbolName:         String   // SF Symbol name, e.g. "cloud.sun.fill"
    let fetchedAt:          Date     // Stale-check guard

    /// Rounded display string: "12°"
    var temperatureDisplay: String {
        "\(Int(temperatureCelsius.rounded()))°"
    }

    /// True when the cached value is older than 30 minutes — caller should re-fetch.
    var isStale: Bool {
        Date.now.timeIntervalSince(fetchedAt) > 1800
    }
}

// MARK: - City Coordinates

/// Latitude/longitude pairs for each Diyanet city preset.
/// Kept separate from `DiyanetCity` to avoid coupling the prayer service to weather.
struct CityCoordinate {
    let latitude:  Double
    let longitude: Double

    static let istanbul = CityCoordinate(latitude: 41.0082, longitude: 28.9784)
    static let ankara   = CityCoordinate(latitude: 39.9334, longitude: 32.8597)
    static let izmir    = CityCoordinate(latitude: 38.4192, longitude: 27.1287)
}

// MARK: - WMO Code → SF Symbol

/// Maps WMO 4677 weather codes to the closest SF Symbol.
/// Only covers codes actually returned by Open-Meteo.
enum WMOSymbol {
    static func sfSymbol(for code: Int) -> String {
        switch code {
        case 0:           return "sun.max"
        case 1:           return "sun.haze"
        case 2:           return "cloud.sun"
        case 3:           return "cloud"
        case 45, 48:      return "cloud.fog"
        case 51, 53, 55:  return "cloud.drizzle"
        case 56, 57:      return "cloud.sleet"
        case 61, 63, 65:  return "cloud.rain"
        case 66, 67:      return "cloud.sleet"
        case 71, 73, 75:  return "cloud.snow"
        case 77:          return "snowflake"
        case 80, 81, 82:  return "cloud.heavyrain"
        case 85, 86:      return "cloud.snow"
        case 95:          return "cloud.bolt"
        case 96, 99:      return "cloud.bolt.rain"
        default:          return "thermometer.medium"
        }
    }
}
