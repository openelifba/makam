import Foundation
import SwiftData

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
/// Values are the exact Turkish names as displayed in the app.
enum TimePeriod: String, Codable, CaseIterable {
    case imsak  = "İmsak"
    case gunes  = "Güneş"
    case ogle   = "Öğle"
    case ikindi = "İkindi"
    case aksam  = "Akşam"
    case yatsi  = "Yatsı"
}

// MARK: - HabitTask

/// A single habit task associated with a prayer period.
/// Persisted locally via SwiftData (no backend required).
@Model
final class HabitTask {
    /// Stable UUID string — generated on creation and never changed.
    var id: String

    /// Short title describing the habit (e.g. "Read Quran").
    var title: String

    /// Calendar date in YYYY-MM-DD format (e.g. "2024-03-14").
    var date: String

    /// The prayer period this task belongs to.
    var timePeriod: TimePeriod

    /// Planned duration in minutes.
    var duration: Int

    /// Optional free-text notes about the task.
    var notes: String?

    /// Whether the task has been completed. Defaults to `false`.
    var isCompleted: Bool

    /// How often this task repeats. Defaults to `.none` (no repeat).
    var repeatFrequency: RepeatFrequency = RepeatFrequency.none

    /// Shared UUID string that links all instances of the same repeat series.
    /// `nil` for tasks that are not part of a recurring series.
    var seriesID: String?

    init(
        id: String = UUID().uuidString,
        title: String,
        date: String,
        timePeriod: TimePeriod,
        duration: Int,
        notes: String? = nil,
        isCompleted: Bool = false,
        repeatFrequency: RepeatFrequency = .none,
        seriesID: String? = nil
    ) {
        self.id = id
        self.title = title
        self.date = date
        self.timePeriod = timePeriod
        self.duration = duration
        self.notes = notes
        self.isCompleted = isCompleted
        self.repeatFrequency = repeatFrequency
        self.seriesID = seriesID
    }
}
