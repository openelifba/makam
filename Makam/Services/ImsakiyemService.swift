// MARK: - ImsakiyemService.swift
// Makam — Networking layer for the Imsakiyem API.
//
// API Base: https://ezanvakti.imsakiyem.com/api
// All responses are wrapped in: { success, code, message, data, meta }
//
// Geographic hierarchy: Country → State → District
// Prayer times are fetched by district ID.

import Foundation

// MARK: - Response Wrapper

private struct ImsakiyemResponse<T: Decodable>: Decodable {
    let success: Bool
    let data: T
}

// MARK: - Location Models

struct ImsakiyemCountry: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let nameEn: String?
    let timezone: String?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case name
        case nameEn = "name_en"
        case timezone
    }
}

struct ImsakiyemState: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let nameEn: String?
    let countryId: String

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case name
        case nameEn = "name_en"
        case countryId = "country_id"
    }
}

struct ImsakiyemDistrict: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let nameEn: String?
    let stateId: String
    let countryId: String

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case name
        case nameEn = "name_en"
        case stateId = "state_id"
        case countryId = "country_id"
    }
}

// MARK: - Prayer Time Models

struct ImsakiyemPrayerTime: Decodable {
    let districtId: String
    let date: String
    let times: ImsakiyemTimes

    enum CodingKeys: String, CodingKey {
        case districtId = "district_id"
        case date
        case times
    }
}

struct ImsakiyemTimes: Decodable {
    let imsak: String
    let gunes: String
    let ogle: String
    let ikindi: String
    let aksam: String
    let yatsi: String
}

// MARK: - Service Errors

enum ImsakiyemServiceError: LocalizedError {
    case invalidURL
    case network(Error)
    case decoding(Error)
    case noDataForToday

    var errorDescription: String? {
        switch self {
        case .invalidURL:        return "Geçersiz API adresi."
        case .network(let e):    return "Ağ hatası: \(e.localizedDescription)"
        case .decoding(let e):   return "Veri ayrıştırma hatası: \(e.localizedDescription)"
        case .noDataForToday:    return "Bugün için namaz vakti bulunamadı."
        }
    }
}

// MARK: - Imsakiyem Service

enum ImsakiyemService {

    private static let baseURL = "https://ezanvakti.imsakiyem.com/api"

    // MARK: - Location Endpoints

    static func fetchCountries() async throws -> [ImsakiyemCountry] {
        guard let url = URL(string: "\(baseURL)/locations/countries") else {
            throw ImsakiyemServiceError.invalidURL
        }
        return try await fetch([ImsakiyemCountry].self, from: url)
    }

    static func fetchStates(countryId: String) async throws -> [ImsakiyemState] {
        var components = URLComponents(string: "\(baseURL)/locations/states")
        components?.queryItems = [URLQueryItem(name: "countryId", value: countryId)]
        guard let url = components?.url else { throw ImsakiyemServiceError.invalidURL }
        return try await fetch([ImsakiyemState].self, from: url)
    }

    static func fetchDistricts(stateId: String) async throws -> [ImsakiyemDistrict] {
        var components = URLComponents(string: "\(baseURL)/locations/districts")
        components?.queryItems = [URLQueryItem(name: "stateId", value: stateId)]
        guard let url = components?.url else { throw ImsakiyemServiceError.invalidURL }
        return try await fetch([ImsakiyemDistrict].self, from: url)
    }

    // MARK: - Prayer Times Endpoint

    static func fetchDailyPrayerTimes(districtId: String) async throws -> ImsakiyemPrayerTime {
        guard let url = URL(string: "\(baseURL)/prayer-times/\(districtId)/daily") else {
            throw ImsakiyemServiceError.invalidURL
        }
        return try await fetch(ImsakiyemPrayerTime.self, from: url)
    }

    // MARK: - Convert to Domain Model

    static func toDailySchedule(from entry: ImsakiyemPrayerTime) -> DailyPrayerSchedule? {
        return makeDailySchedule(from: entry)
    }

    // MARK: - Private Helpers

    private static func isToday(_ dateString: String) -> Bool {
        // API returns ISO 8601: "2026-03-12T00:00:00.000Z"
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: dateString) {
            return Calendar.current.isDateInToday(date)
        }
        // Fallback: parse YYYY-MM-DD prefix
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        if let date = fmt.date(from: String(dateString.prefix(10))) {
            return Calendar.current.isDateInToday(date)
        }
        return false
    }

    private static func makeDailySchedule(from entry: ImsakiyemPrayerTime) -> DailyPrayerSchedule? {
        let today = Calendar.current.startOfDay(for: Date())
        let t = entry.times
        let timeStrings = [t.imsak, t.gunes, t.ogle, t.ikindi, t.aksam, t.yatsi]

        let prayers: [Prayer] = timeStrings.enumerated().compactMap { index, timeStr in
            guard let prayerDate = parseTime(timeStr, on: today) else { return nil }
            let meta = PrayerMetadata.catalogue[index]
            return Prayer(
                id: index,
                name: meta.name,
                arabicName: meta.arabicName,
                symbol: meta.symbol,
                time: prayerDate
            )
        }

        guard prayers.count == 6 else { return nil }
        return DailyPrayerSchedule(date: today, prayers: prayers)
    }

    private static func parseTime(_ timeStr: String, on day: Date) -> Date? {
        let parts = timeStr.split(separator: ":").compactMap { Int($0) }
        guard parts.count >= 2 else { return nil }
        return Calendar.current.date(
            bySettingHour: parts[0],
            minute: parts[1],
            second: 0,
            of: day
        )
    }

    // MARK: - Generic Fetch

    private static func fetch<T: Decodable>(_ type: T.Type, from url: URL) async throws -> T {
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let data: Data
        do {
            let (responseData, _) = try await URLSession.shared.data(for: request)
            data = responseData
        } catch {
            throw ImsakiyemServiceError.network(error)
        }

        do {
            let response = try JSONDecoder().decode(ImsakiyemResponse<T>.self, from: data)
            return response.data
        } catch {
            throw ImsakiyemServiceError.decoding(error)
        }
    }
}
