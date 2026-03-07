// MARK: - PrayerModels.swift
// Makam — Data layer models for Diyanet prayer time API.
//
// Architecture note: Two distinct model layers are intentional.
//   • `DailyPrayerResponse` is a raw Codable that mirrors the Diyanet JSON exactly.
//   • `Prayer` is the domain model the UI and widget consume — it carries resolved
//     `Date` values so views never perform string→Date parsing.

import Foundation

// MARK: - Raw Diyanet API Response

/// Mirrors the Diyanet Namaz Vakitleri JSON structure for a single day.
/// Diyanet returns prayer times as "HH:mm" strings within a date-keyed payload.
///
/// Example JSON (per day object inside the API array):
/// ```json
/// {
///   "MiladiTarihKisa": "07.03.2026",
///   "Imsak":  "05:23",
///   "Gunes":  "06:52",
///   "Ogle":   "12:15",
///   "Ikindi": "15:30",
///   "Aksam":  "17:42",
///   "Yatsi":  "19:05"
/// }
/// ```
struct DailyPrayerResponse: Codable {
    let miladiTarihKisa: String  // "07.03.2026"
    let imsak:           String  // Fajr / Pre-dawn
    let gunes:           String  // Sunrise
    let ogle:            String  // Dhuhr / Noon
    let ikindi:          String  // Asr / Afternoon
    let aksam:           String  // Maghrib / Sunset
    let yatsi:           String  // Isha / Night

    // Diyanet API uses Turkish camelCase keys
    enum CodingKeys: String, CodingKey {
        case miladiTarihKisa = "MiladiTarihKisa"
        case imsak  = "Imsak"
        case gunes  = "Gunes"
        case ogle   = "Ogle"
        case ikindi = "Ikindi"
        case aksam  = "Aksam"
        case yatsi  = "Yatsi"
    }
}

// MARK: - Diyanet Top-Level Wrapper

/// The Diyanet API wraps results in a data envelope.
struct DiyanetAPIResponse: Codable {
    let data: [DailyPrayerResponse]

    enum CodingKeys: String, CodingKey {
        case data = "data"
    }
}

// MARK: - Domain Model

/// A single, resolved prayer with its exact `Date` and display metadata.
struct Prayer: Identifiable, Equatable {
    let id:          Int     // Ordering index (0 = Imsak … 5 = Yatsi)
    let name:        String  // Turkish name shown in the widget
    let arabicName:  String  // Subtle sub-label for spiritual context
    let symbol:      String  // SF Symbol name for lock-screen accessory
    let time:        Date

    // Equatable by stable identity
    static func == (lhs: Prayer, rhs: Prayer) -> Bool {
        lhs.id == rhs.id && lhs.time == rhs.time
    }
}

// MARK: - Daily Prayer Schedule (Domain)

/// All six prayers for one calendar day, fully resolved to `Date` values.
struct DailyPrayerSchedule {
    let date:    Date
    let prayers: [Prayer]   // Always ordered: Imsak → Gunes → Öğle → İkindi → Akşam → Yatsı

    // Convenience accessors
    var imsak:  Prayer { prayers[0] }
    var gunes:  Prayer { prayers[1] }
    var ogle:   Prayer { prayers[2] }
    var ikindi: Prayer { prayers[3] }
    var aksam:  Prayer { prayers[4] }
    var yatsi:  Prayer { prayers[5] }
}

// MARK: - Active Prayer Context

/// What the widget actually displays at any given moment.
struct PrayerContext {
    let current:        Prayer   // The prayer window we are currently inside
    let next:           Prayer   // The upcoming prayer
    let windowStart:    Date     // When the current prayer window began
    let windowEnd:      Date     // When the next prayer starts (= windowEnd)
    let countdownDate:  Date     // Convenience alias for next.time

    /// 0.0 → 1.0 progress through the current prayer window at `referenceDate`.
    func elapsedFraction(at referenceDate: Date = .now) -> Double {
        let total    = windowEnd.timeIntervalSince(windowStart)
        let elapsed  = referenceDate.timeIntervalSince(windowStart)
        guard total > 0 else { return 0 }
        return min(max(elapsed / total, 0), 1)
    }

    /// Remaining seconds until the next prayer.
    func secondsRemaining(at referenceDate: Date = .now) -> TimeInterval {
        max(windowEnd.timeIntervalSince(referenceDate), 0)
    }
}

// MARK: - Prayer Metadata Catalogue

/// Static lookup for display strings and symbols — keeps domain models clean.
enum PrayerMetadata {
    struct Info {
        let name:       String
        let arabicName: String
        let symbol:     String
    }

    /// Ordered to match Diyanet index (0–5).
    static let catalogue: [Info] = [
        Info(name: "İmsak",   arabicName: "الفجر",   symbol: "moon.stars"),
        Info(name: "Güneş",   arabicName: "الشروق",  symbol: "sunrise"),
        Info(name: "Öğle",    arabicName: "الظهر",   symbol: "sun.max"),
        Info(name: "İkindi",  arabicName: "العصر",   symbol: "sun.haze"),
        Info(name: "Akşam",   arabicName: "المغرب",  symbol: "sunset"),
        Info(name: "Yatsı",   arabicName: "العشاء",  symbol: "moon.zzz"),
    ]
}
