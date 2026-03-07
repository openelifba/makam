// MARK: - PrayerModels.swift
// Makam — Data layer models for Diyanet prayer time API.
//
// Architecture note: Two distinct model layers are intentional.
//   • `DailyPrayerResponse` is a raw Codable that mirrors the Diyanet JSON exactly.
//   • `Prayer` is the domain model the UI and widget consume — it carries resolved
//     `Date` values so views never perform string→Date parsing.

import Foundation

// MARK: - Aladhan API Response Models

struct AladhanAPIResponse: Codable {
    let code: Int
    let status: String
    let data: [AladhanDayData]
}

struct AladhanDayData: Codable {
    let timings: AladhanTimings
    let date: AladhanDate
}

struct AladhanTimings: Codable {
    let fajr:    String
    let sunrise: String
    let dhuhr:   String
    let asr:     String
    let sunset:  String
    let maghrib: String
    let isha:    String
    let imsak:   String

    enum CodingKeys: String, CodingKey {
        case fajr    = "Fajr"
        case sunrise = "Sunrise"
        case dhuhr   = "Dhuhr"
        case asr     = "Asr"
        case sunset  = "Sunset"
        case maghrib = "Maghrib"
        case isha    = "Isha"
        case imsak   = "Imsak"
    }
}

struct AladhanDate: Codable {
    let timestamp: String
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
    func elapsedFraction(at referenceDate: Date = Date()) -> Double {
        let total    = windowEnd.timeIntervalSince(windowStart)
        let elapsed  = referenceDate.timeIntervalSince(windowStart)
        guard total > 0 else { return 0 }
        return min(max(elapsed / total, 0), 1)
    }

    /// Remaining seconds until the next prayer.
    func secondsRemaining(at referenceDate: Date = Date()) -> TimeInterval {
        max(windowEnd.timeIntervalSince(referenceDate), 0)
    }

    /// Short countdown: "01:23:45"
    func countdownHMS(at referenceDate: Date = Date()) -> String {
        PrayerCalculator.countdownHMS(to: windowEnd, from: referenceDate)
    }

    /// Human-readable countdown: "1s 23d"
    func countdownString(at referenceDate: Date = Date()) -> String {
        PrayerCalculator.countdownString(to: windowEnd, from: referenceDate)
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
