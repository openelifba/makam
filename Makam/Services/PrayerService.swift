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
    let id:   Int
    let slug: String
    let name: String

    // Presets for common cities
    static let istanbul  = DiyanetCity(id: 9541,  slug: "istanbul",  name: "İstanbul")
    static let ankara    = DiyanetCity(id: 9206,  slug: "ankara",    name: "Ankara")
    static let izmir     = DiyanetCity(id: 9560,  slug: "izmir",     name: "İzmir")
}

// MARK: - Prayer Service

/// Fetches and decodes Diyanet prayer times. Stateless and actor-isolated via
/// Swift Concurrency — safe to call from both the main app and the widget extension.
enum PrayerService {

    // MARK: Constants

    private static let baseURL   = "https://namazvakitleri.diyanet.gov.tr/en-US"
    private static let appGroup  = "group.com.makam.shared"   // Set in Xcode → Signing & Capabilities

    // Shared UserDefaults container (app + widget extension)
    static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroup)
    }

    // MARK: - Fetch

    /// Fetches prayer times for a given city and month.
    /// Returns a decoded array of `DailyPrayerSchedule` (one per day in the API response).
    ///
    /// - Parameters:
    ///   - city:  Diyanet city configuration.
    ///   - month: Month number (1–12). Defaults to current month.
    ///   - year:  Year (e.g. 2026). Defaults to current year.
    static func fetchMonthlySchedule(
        for city: DiyanetCity = .istanbul,
        month: Int? = nil,
        year:  Int? = nil
    ) async throws -> [DailyPrayerSchedule] {

        let calendar   = Calendar.current
        let components = calendar.dateComponents([.month, .year], from: .now)
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

        let rawSchedules: [DailyPrayerResponse]
        do {
            // Diyanet wraps results: { "data": [...] }
            let wrapper = try JSONDecoder().decode(DiyanetAPIResponse.self, from: data)
            rawSchedules = wrapper.data
        } catch {
            // Fallback: try decoding as a bare array
            do {
                rawSchedules = try JSONDecoder().decode([DailyPrayerResponse].self, from: data)
            } catch {
                throw PrayerServiceError.decoding(error)
            }
        }

        return rawSchedules.compactMap { toDomainModel($0) }
    }

    // MARK: - Convenience: Fetch & Cache Today

    /// Fetches today's prayer schedule and persists it to the shared App Group.
    /// The widget's `TimelineProvider` calls this to populate timeline entries.
    @discardableResult
    static func fetchAndCacheToday(for city: DiyanetCity = .istanbul) async throws -> DailyPrayerSchedule {
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
    /// Returns `nil` if no cache exists — widget should show a placeholder.
    static func cachedTodaySchedule() -> DailyPrayerSchedule? {
        guard
            let data  = sharedDefaults?.data(forKey: "makam.todaySchedule"),
            let cache = try? JSONDecoder().decode(CachedSchedule.self, from: data)
        else { return nil }
        return cache.toDailySchedule()
    }

    // MARK: - Private Helpers

    private static func buildURL(city: DiyanetCity, month: Int, year: Int) -> URL? {
        // Diyanet monthly endpoint pattern
        var components        = URLComponents(string: "\(baseURL)/\(city.id)/prayer-time-for-\(city.slug)")
        components?.queryItems = [
            URLQueryItem(name: "monthId", value: "\(year)\(String(format: "%02d", month))")
        ]
        return components?.url
    }

    /// Converts raw Diyanet strings into a fully resolved `DailyPrayerSchedule`.
    private static func toDomainModel(_ raw: DailyPrayerResponse) -> DailyPrayerSchedule? {
        guard let date = parseDate(raw.miladiTarihKisa) else { return nil }

        let timeStrings = [raw.imsak, raw.gunes, raw.ogle, raw.ikindi, raw.aksam, raw.yatsi]
        let prayers = timeStrings.enumerated().compactMap { (index, timeStr) -> Prayer? in
            guard let prayerDate = parseTime(timeStr, on: date) else { return nil }
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

    // "07.03.2026" → Date (midnight, local calendar)
    private static func parseDate(_ string: String) -> Date? {
        let formatter        = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy"
        formatter.locale     = Locale(identifier: "tr_TR")
        return formatter.date(from: string)
    }

    // "05:23" on a given calendar day → Date
    private static func parseTime(_ timeStr: String, on day: Date) -> Date? {
        let parts = timeStr.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2 else { return nil }
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
