// MARK: - EzanVaktiService.swift
// Makam — Networking layer for the Ezan Vakti API (Diyanet İşleri Başkanlığı).
//
// API Base: https://ezanvakti.emushaf.net
// Geographic hierarchy: Country (Ülke) → City (Şehir) → District (İlçe)
// Prayer times are fetched by district ID.

import Foundation

// MARK: - Location Models

struct EzanVaktiUlke: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let nameEn: String

    enum CodingKeys: String, CodingKey {
        case id     = "UlkeID"
        case name   = "UlkeAdi"
        case nameEn = "UlkeAdiEn"
    }
}

struct EzanVaktiSehir: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let nameEn: String

    enum CodingKeys: String, CodingKey {
        case id     = "SehirID"
        case name   = "SehirAdi"
        case nameEn = "SehirAdiEn"
    }
}

struct EzanVaktiIlce: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let nameEn: String

    enum CodingKeys: String, CodingKey {
        case id     = "IlceID"
        case name   = "IlceAdi"
        case nameEn = "IlceAdiEn"
    }
}

// MARK: - Prayer Times Model

struct EzanVaktiVakit: Codable {
    let miladiTarihUzunIso8601: String   // e.g. "2026-04-02T00:00:00.0000000+03:00"
    let imsak: String
    let gunes: String
    let ogle: String
    let ikindi: String
    let aksam: String
    let yatsi: String

    enum CodingKeys: String, CodingKey {
        case miladiTarihUzunIso8601 = "MiladiTarihUzunIso8601"
        case imsak  = "Imsak"
        case gunes  = "Gunes"
        case ogle   = "Ogle"
        case ikindi = "Ikindi"
        case aksam  = "Aksam"
        case yatsi  = "Yatsi"
    }
}

// MARK: - Service Errors

enum EzanVaktiServiceError: LocalizedError {
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

// MARK: - Ezan Vakti Service

enum EzanVaktiService {

    private static let baseURL = "https://ezanvakti.emushaf.net"

    // MARK: - Location Endpoints

    static func fetchCountries() async throws -> [EzanVaktiUlke] {
        guard let url = URL(string: "\(baseURL)/ulkeler") else {
            throw EzanVaktiServiceError.invalidURL
        }
        return try await fetch([EzanVaktiUlke].self, from: url)
    }

    static func fetchCities(countryId: String) async throws -> [EzanVaktiSehir] {
        guard let url = URL(string: "\(baseURL)/sehirler/\(countryId)") else {
            throw EzanVaktiServiceError.invalidURL
        }
        return try await fetch([EzanVaktiSehir].self, from: url)
    }

    static func fetchDistricts(cityId: String) async throws -> [EzanVaktiIlce] {
        guard let url = URL(string: "\(baseURL)/ilceler/\(cityId)") else {
            throw EzanVaktiServiceError.invalidURL
        }
        return try await fetch([EzanVaktiIlce].self, from: url)
    }

    // MARK: - Prayer Times Endpoint

    static func fetchTodayPrayerTimes(districtId: String) async throws -> EzanVaktiVakit {
        guard let url = URL(string: "\(baseURL)/vakitler/\(districtId)") else {
            throw EzanVaktiServiceError.invalidURL
        }
        let vakitler = try await fetch([EzanVaktiVakit].self, from: url)
        guard let vakit = vakitler.first(where: { parseDate($0) != nil && Calendar.current.isDateInToday(parseDate($0)!) }) else {
            throw EzanVaktiServiceError.noDataForToday
        }
        return vakit
    }

    // MARK: - Convert to Domain Model

    static func toDailySchedule(from vakit: EzanVaktiVakit) -> DailyPrayerSchedule? {
        guard let day = parseDate(vakit) else { return nil }
        let today = Calendar.current.startOfDay(for: day)

        let timeStrings = [vakit.imsak, vakit.gunes, vakit.ogle, vakit.ikindi, vakit.aksam, vakit.yatsi]
        let prayers: [Prayer] = timeStrings.enumerated().compactMap { index, timeStr in
            guard let prayerDate = parseTime(timeStr, on: today) else { return nil }
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
        return DailyPrayerSchedule(date: today, prayers: prayers)
    }

    // MARK: - Private Helpers

    private static func parseDate(_ vakit: EzanVaktiVakit) -> Date? {
        // "2026-04-02T00:00:00.0000000+03:00" — parse with timezone so isDateInToday is accurate
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return iso.date(from: vakit.miladiTarihUzunIso8601)
    }

    private static func parseTime(_ timeStr: String, on day: Date) -> Date? {
        let parts = timeStr.split(separator: ":").compactMap { Int($0) }
        guard parts.count >= 2 else { return nil }
        return Calendar.current.date(
            bySettingHour: parts[0],
            minute:        parts[1],
            second:        0,
            of:            day
        )
    }

    private static func fetch<T: Decodable>(_ type: T.Type, from url: URL) async throws -> T {
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let data: Data
        do {
            let (responseData, _) = try await URLSession.shared.data(for: request)
            data = responseData
        } catch {
            throw EzanVaktiServiceError.network(error)
        }

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw EzanVaktiServiceError.decoding(error)
        }
    }
}
