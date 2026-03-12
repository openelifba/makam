// MARK: - WeatherModels.swift
// Makam — Domain models and API response types for weather integration.
//
// Data source: Open-Meteo API (https://open-meteo.com)
// Free, no API key required. Returns WMO weather interpretation codes.

import Foundation

// MARK: - Weather State

enum WeatherState {
    case idle
    case loading
    case loaded(WeatherSnapshot)
    case failed
}

// MARK: - Domain Model

/// Resolved weather data ready for display — all units pre-converted.
struct WeatherSnapshot {
    let sfSymbol:       String   // SF Symbol name (e.g. "cloud.sun.fill")
    let temperature:    Int      // Celsius, rounded
    let feelsLike:      Int      // Celsius, rounded
    let humidity:       Int      // Percent 0–100
    let windSpeed:      Int      // km/h, rounded
    let shortCondition: String   // Turkish label, ≤ 12 chars
    let sunrise:        Date
    let sunset:         Date
}

// MARK: - Open-Meteo API Response (Codable)

struct OpenMeteoResponse: Codable {
    let current: OpenMeteoCurrent
    let daily:   OpenMeteoDaily
}

struct OpenMeteoCurrent: Codable {
    let temperature2m:       Double
    let apparentTemperature: Double
    let relativeHumidity2m:  Int
    let windspeed10m:        Double
    let weatherCode:         Int

    enum CodingKeys: String, CodingKey {
        case temperature2m       = "temperature_2m"
        case apparentTemperature = "apparent_temperature"
        case relativeHumidity2m  = "relative_humidity_2m"
        case windspeed10m        = "windspeed_10m"
        case weatherCode         = "weather_code"
    }
}

struct OpenMeteoDaily: Codable {
    let sunrise: [String]
    let sunset:  [String]
}
