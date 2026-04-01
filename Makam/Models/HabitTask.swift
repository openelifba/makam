import Foundation

// MARK: - RepeatFrequency

/// How often a habit task should repeat.
enum RepeatFrequency: String, Codable, CaseIterable {
    case none    = "none"
    case daily   = "daily"
    case weekly  = "weekly"
    case monthly = "monthly"
    case yearly  = "yearly"
    case custom  = "custom"

    var label: String {
        switch self {
        case .none:    return "Tekrar yok"
        case .daily:   return "Günlük"
        case .weekly:  return "Haftalık"
        case .monthly: return "Aylık"
        case .yearly:  return "Yıllık"
        case .custom:  return "Özel"
        }
    }
}

// MARK: - TimePeriod

/// The six Islamic prayer periods used to schedule habit tasks.
enum TimePeriod: String, Codable, CaseIterable {
    case fajr    = "fajr"
    case shuruq  = "shuruq"
    case dhuhr   = "dhuhr"
    case asr     = "asr"
    case maghrib = "maghrib"
    case isha    = "isha"
}

// MARK: - HabitTask

/// A single habit task associated with a prayer period.
/// Backed by the Makam backend API.
struct HabitTask: Identifiable, Codable, Hashable {
    let id: String
    var title: String
    var date: String
    var timePeriod: TimePeriod
    var duration: Int
    var notes: String?
    var isCompleted: Bool
    var repeatFrequency: RepeatFrequency
    var seriesID: String?

    enum CodingKeys: String, CodingKey {
        case id, title, date, timePeriod, duration, notes, isCompleted, repeatFrequency
        case seriesID = "seriesId"
    }
}
