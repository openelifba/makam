// MARK: - PrayerService.swift
// Makam — Lightweight async/await networking for Diyanet prayer times.
//
// Architecture note: `PrayerService` is a pure value-type namespace (enum with
// no cases) — no singletons, no state. Callers own caching via `@AppStorage`
// or a dedicated store. This keeps the service fully testable without mocks.
//
// Diyanet API endpoint (public, no auth required):
//   GET https://namazvakitleri.diyanet.gov.tr/en-US/{cityId}/prayer-time-for-{citySlug}
//
// The widget extension shares the same `PrayerService` via a shared App Group,
// writing decoded schedules to `UserDefaults(suiteName:)`.

import Foundation

// MARK: - Service Errors

enum PrayerServiceError: LocalizedError {
    case invalidURL
    case network(Error)
    case decoding(Error)
    case noDataForToday

    var errorDescription: String? {
        switch self {
        case .invalidURL:          return "Invalid API endpoint URL."
        case .network(let e):      return "Network error: \(e.localizedDescription)"
        case .decoding(let e):     return "Could not parse prayer times: \(e.localizedDescription)"
        case .noDataForToday:      return "No prayer data available for today."
        }
    }
}

// MARK: - City Configuration

/// Diyanet city identifier — extend as needed for multi-city support.
struct DiyanetCity {
    let id:        Int
    let name:      String
    let cityName:  String
    let country:   String
    let latitude:  Double   // WGS84, used for weather API
    let longitude: Double   // WGS84, used for weather API

    // Presets for common cities
    static let istanbul  = DiyanetCity(id: 9541, name: "İstanbul", cityName: "Istanbul", country: "Turkey", latitude: 41.0082, longitude: 28.9784)
    static let ankara    = DiyanetCity(id: 9206, name: "Ankara",   cityName: "Ankara",   country: "Turkey", latitude: 39.9334, longitude: 32.8597)
    static let izmir     = DiyanetCity(id: 9560, name: "İzmir",    cityName: "Izmir",    country: "Turkey", latitude: 38.4192, longitude: 27.1287)
}

// MARK: - Prayer Service

/// Fetches and decodes prayer times via Aladhan API (using Diyanet method).
enum PrayerService {

    // MARK: Constants

    private static let baseURL   = "https://api.aladhan.com/v1/calendarByCity"
    private static let appGroup  = "group.com.makam.shared"   // Set in Xcode → Signing & Capabilities

    // Shared UserDefaults container (app + widget extension)
    static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroup)
    }

    // MARK: - Fetch

    /// Fetches prayer times for a given city and month.
    static func fetchMonthlySchedule(
        for city: DiyanetCity = .ankara,
        month: Int? = nil,
        year:  Int? = nil
    ) async throws -> [DailyPrayerSchedule] {

        let calendar   = Calendar.current
        let components = calendar.dateComponents([.month, .year], from: Date())
        let resolvedMonth = month ?? components.month ?? 3
        let resolvedYear  = year  ?? components.year  ?? 2026

        guard let url = buildURL(city: city, month: resolvedMonth, year: resolvedYear) else {
            throw PrayerServiceError.invalidURL
        }

        let data: Data
        do {
            let (responseData, _) = try await URLSession.shared.data(from: url)
            data = responseData
        } catch {
            throw PrayerServiceError.network(error)
        }

        do {
            let response = try JSONDecoder().decode(AladhanAPIResponse.self, from: data)
            return response.data.compactMap { toDomainModel($0) }
        } catch {
            throw PrayerServiceError.decoding(error)
        }
    }

    // MARK: - Convenience: Fetch & Cache Today

    /// Fetches today's prayer schedule and persists it to the shared App Group.
    @discardableResult
    static func fetchAndCacheToday(for city: DiyanetCity = .ankara) async throws -> DailyPrayerSchedule {
        let schedules = try await fetchMonthlySchedule(for: city)

        guard let today = schedules.first(where: { Calendar.current.isDateInToday($0.date) }) else {
            throw PrayerServiceError.noDataForToday
        }

        // Persist encoded JSON to shared defaults so the widget can read it offline
        if let encoded = try? JSONEncoder().encode(CachedSchedule(from: today)) {
            sharedDefaults?.set(encoded, forKey: "makam.todaySchedule")
        }

        return today
    }

    // MARK: - Read Cache (Widget-safe, no network)

    /// Reads the last-cached schedule from the shared App Group.
    static func cachedTodaySchedule() -> DailyPrayerSchedule? {
        guard
            let data  = sharedDefaults?.data(forKey: "makam.todaySchedule"),
            let cache = try? JSONDecoder().decode(CachedSchedule.self, from: data)
        else { return nil }
        return cache.toDailySchedule()
    }

    // MARK: - Private Helpers

    private static func buildURL(city: DiyanetCity, month: Int, year: Int) -> URL? {
        // Aladhan monthly endpoint pattern: /year/month?city=...&country=...&method=13
        let urlString = "\(baseURL)/\(year)/\(month)"
        var components = URLComponents(string: urlString)
        components?.queryItems = [
            URLQueryItem(name: "city",    value: city.cityName),
            URLQueryItem(name: "country", value: city.country),
            URLQueryItem(name: "method",  value: "13") // Diyanet
        ]
        return components?.url
    }

    /// Converts Aladhan API strings into a fully resolved `DailyPrayerSchedule`.
    private static func toDomainModel(_ raw: AladhanDayData) -> DailyPrayerSchedule? {
        guard let date = parseAladhanTimestamp(raw.date.timestamp) else { return nil }

        let t = raw.timings
        // Map Aladhan timings to Diyanet catalogue: İmsak, Güneş, Öğle, İkindi, Akşam, Yatsı
        let timeStrings = [t.fajr, t.sunrise, t.dhuhr, t.asr, t.maghrib, t.isha]
        
        let prayers = timeStrings.enumerated().compactMap { (index, timeStr) -> Prayer? in
            // Aladhan returns times like "05:58 (TRT)" or just "05:58"
            let cleanTime = timeStr.components(separatedBy: " ").first ?? timeStr
            guard let prayerDate = parseTime(cleanTime, on: date) else { return nil }
            let meta = PrayerMetadata.catalogue[index]
            return Prayer(
                id:         index,
                name:       meta.name,
                arabicName: meta.arabicName,
                symbol:     meta.symbol,
                time:       prayerDate
            )
        }

        guard prayers.count == 6 else { return nil }
        return DailyPrayerSchedule(date: date, prayers: prayers)
    }

    private static func parseAladhanTimestamp(_ timestamp: String) -> Date? {
        guard let interval = TimeInterval(timestamp) else { return nil }
        // Aladhan timestamp is for noon or midnight? Usually it's a day marker.
        // We want the start of that day (midnight).
        let date = Date(timeIntervalSince1970: interval)
        return Calendar.current.startOfDay(for: date)
    }

    // "05:23" on a given calendar day → Date
    private static func parseTime(_ timeStr: String, on day: Date) -> Date? {
        let parts = timeStr.split(separator: ":").compactMap { Int($0) }
        guard parts.count >= 2 else { return nil }
        return Calendar.current.date(
            bySettingHour:   parts[0],
            minute:          parts[1],
            second:          0,
            of:              day
        )
    }
}

// MARK: - Cache Codable (Widget-safe serialization)

/// A flat, Codable representation for UserDefaults persistence.
/// Uses TimeInterval (Double) to avoid Date encoding fragility.
private struct CachedSchedule: Codable {
    let dayTimestamp:    TimeInterval   // The calendar day (midnight)
    let prayerTimestamps: [TimeInterval] // 6 values: Imsak → Yatsı

    init(from schedule: DailyPrayerSchedule) {
        dayTimestamp     = schedule.date.timeIntervalSince1970
        prayerTimestamps = schedule.prayers.map { $0.time.timeIntervalSince1970 }
    }

    func toDailySchedule() -> DailyPrayerSchedule? {
        guard prayerTimestamps.count == 6 else { return nil }
        let day = Date(timeIntervalSince1970: dayTimestamp)
        let prayers = prayerTimestamps.enumerated().map { (index, ts) -> Prayer in
            let meta = PrayerMetadata.catalogue[index]
            return Prayer(
                id:         index,
                name:       meta.name,
                arabicName: meta.arabicName,
                symbol:     meta.symbol,
                time:       Date(timeIntervalSince1970: ts)
            )
        }
        return DailyPrayerSchedule(date: day, prayers: prayers)
    }
}
