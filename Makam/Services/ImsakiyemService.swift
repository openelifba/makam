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

struct ImsakiyemTimes {
    let imsak: String
    let gunes: String
    let ogle: String
    let ikindi: String
    let aksam: String
    let yatsi: String
}

struct ImsakiyemPrayerTime: Decodable {
    let districtId: String
    let date: String
    let times: ImsakiyemTimes

    // The API may return prayer times either as a nested `times` object with
    // lowercase keys, or as flat top-level fields with capitalised keys
    // (e.g. "Imsak", "Gunes", …). Both layouts are handled below.
    private enum CodingKeys: String, CodingKey {
        case districtId = "district_id"
        case date
        // nested layout
        case times
        // flat capitalised layout
        case imsakCap  = "Imsak"
        case gunesCap  = "Gunes"
        case ogleCap   = "Ogle"
        case ikindiCap = "Ikindi"
        case aksamCap  = "Aksam"
        case yatsiCap  = "Yatsi"
        // flat lowercase layout (fallback)
        case imsakLow  = "imsak"
        case gunesLow  = "gunes"
        case ogleLow   = "ogle"
        case ikindiLow = "ikindi"
        case aksamLow  = "aksam"
        case yatsiLow  = "yatsi"
    }

    private enum NestedTimesKeys: String, CodingKey {
        case imsak, gunes, ogle, ikindi, aksam, yatsi
        case imsakCap  = "Imsak"
        case gunesCap  = "Gunes"
        case ogleCap   = "Ogle"
        case ikindiCap = "Ikindi"
        case aksamCap  = "Aksam"
        case yatsiCap  = "Yatsi"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        districtId = try c.decode(String.self, forKey: .districtId)
        date       = try c.decode(String.self, forKey: .date)

        // 1. Try nested `times` object (lowercase or capitalised inside)
        if c.contains(.times),
           let nested = try? c.nestedContainer(keyedBy: NestedTimesKeys.self, forKey: .times) {
            let imsak  = (try? nested.decode(String.self, forKey: .imsak))  ?? (try nested.decode(String.self, forKey: .imsakCap))
            let gunes  = (try? nested.decode(String.self, forKey: .gunes))  ?? (try nested.decode(String.self, forKey: .gunesCap))
            let ogle   = (try? nested.decode(String.self, forKey: .ogle))   ?? (try nested.decode(String.self, forKey: .ogleCap))
            let ikindi = (try? nested.decode(String.self, forKey: .ikindi)) ?? (try nested.decode(String.self, forKey: .ikindiCap))
            let aksam  = (try? nested.decode(String.self, forKey: .aksam))  ?? (try nested.decode(String.self, forKey: .aksamCap))
            let yatsi  = (try? nested.decode(String.self, forKey: .yatsi))  ?? (try nested.decode(String.self, forKey: .yatsiCap))
            times = ImsakiyemTimes(imsak: imsak, gunes: gunes, ogle: ogle,
                                   ikindi: ikindi, aksam: aksam, yatsi: yatsi)
            return
        }

        // 2. Flat capitalised keys ("Imsak", "Gunes", …)
        if c.contains(.imsakCap) {
            times = ImsakiyemTimes(
                imsak:  try c.decode(String.self, forKey: .imsakCap),
                gunes:  try c.decode(String.self, forKey: .gunesCap),
                ogle:   try c.decode(String.self, forKey: .ogleCap),
                ikindi: try c.decode(String.self, forKey: .ikindiCap),
                aksam:  try c.decode(String.self, forKey: .aksamCap),
                yatsi:  try c.decode(String.self, forKey: .yatsiCap)
            )
            return
        }

        // 3. Flat lowercase keys ("imsak", "gunes", …)
        times = ImsakiyemTimes(
            imsak:  try c.decode(String.self, forKey: .imsakLow),
            gunes:  try c.decode(String.self, forKey: .gunesLow),
            ogle:   try c.decode(String.self, forKey: .ogleLow),
            ikindi: try c.decode(String.self, forKey: .ikindiLow),
            aksam:  try c.decode(String.self, forKey: .aksamLow),
            yatsi:  try c.decode(String.self, forKey: .yatsiLow)
        )
    }
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
