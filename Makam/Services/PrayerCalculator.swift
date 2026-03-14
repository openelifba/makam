// MARK: - PrayerCalculator.swift
// Makam — Pure business logic for determining the active prayer window.
//
// Architecture note: This is a pure, dependency-free value layer. Every function
// is static and takes explicit `Date` parameters so it is trivially unit-testable
// and usable from both the main app and the widget extension without any shared state.

import Foundation

enum PrayerCalculator {

    // MARK: - Core: Active Prayer Context

    /// Returns the `PrayerContext` (current prayer, next prayer, window bounds)
    /// for a given reference date and daily schedule.
    ///
    /// Algorithm:
    ///   • The "active" prayer is the last one whose time is ≤ referenceDate.
    ///   • The "next" prayer is the immediately following one.
    ///   • After Yatsı ends (i.e. past midnight into the next day) we wrap:
    ///     current = Yatsı, next = tomorrow's Imsak.
    ///
    /// - Parameters:
    ///   - schedule:      Today's resolved `DailyPrayerSchedule`.
    ///   - tomorrow:      Optional next-day schedule used to find tomorrow's Imsak
    ///                    when the current time is after Yatsı.
    ///   - referenceDate: Defaults to `Date.now`; pass explicitly for testing.
    static func context(
        for schedule:      DailyPrayerSchedule,
        tomorrow:          DailyPrayerSchedule? = nil,
        at referenceDate:  Date = Date()
    ) -> PrayerContext? {
        let prayers = schedule.prayers

        // Find the last prayer whose start time has passed
        let passedPrayers = prayers.filter { $0.time <= referenceDate }

        guard let current = passedPrayers.last else {
            // Before Imsak: synthesise yesterday's Yatsı so the card stays visible.
            // Inverse of syntheticTomorrowImsak: Imsak ≈ Yatsı + 8 h  →  Yatsı ≈ Imsak − 8 h
            let imsak      = prayers[0]
            let yatsiMeta  = PrayerMetadata.catalogue[5]
            let yatsiTime  = imsak.time.addingTimeInterval(-8 * 3600)
            let syntheticYatsi = Prayer(
                id:         5,
                name:       yatsiMeta.name,
                arabicName: yatsiMeta.arabicName,
                symbol:     yatsiMeta.symbol,
                time:       yatsiTime
            )
            return PrayerContext(
                current:       syntheticYatsi,
                next:          imsak,
                windowStart:   yatsiTime,
                windowEnd:     imsak.time,
                countdownDate: imsak.time
            )
        }

        let currentIndex = current.id   // 0–5

        if currentIndex < prayers.count - 1 {
            // Normal case: next prayer is the same day
            let next = prayers[currentIndex + 1]
            return PrayerContext(
                current:       current,
                next:          next,
                windowStart:   current.time,
                windowEnd:     next.time,
                countdownDate: next.time
            )
        } else {
            // After Yatsı: wrap to tomorrow's Imsak
            let tomorrowImsak = tomorrow?.imsak ?? syntheticTomorrowImsak(from: current)
            return PrayerContext(
                current:       current,
                next:          tomorrowImsak,
                windowStart:   current.time,
                windowEnd:     tomorrowImsak.time,
                countdownDate: tomorrowImsak.time
            )
        }
    }

    // MARK: - Timeline Entry Dates

    /// Returns the ordered list of `Date` values at which the widget timeline
    /// should refresh — one entry per prayer + the start of the following day.
    ///
    /// The `TimelineProvider` calls this to build `TimelineEntry` objects.
    static func timelineRefreshDates(for schedule: DailyPrayerSchedule) -> [Date] {
        var dates = schedule.prayers.map(\.time)
        // Add a midnight entry so the timeline reloads fresh data for tomorrow
        if let midnight = nextMidnight(after: schedule.date) {
            dates.append(midnight)
        }
        return dates.sorted()
    }

    // MARK: - Countdown Formatting

    /// Human-readable countdown string: "1s 23d" (saat/dakika in Turkish).
    static func countdownString(to target: Date, from reference: Date = Date()) -> String {
        let seconds = Int(target.timeIntervalSince(reference))
        guard seconds > 0 else { return "—" }

        let hours   = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs    = seconds % 60

        if hours > 0 {
            return String(format: "%ds %02dd", hours, minutes)
        } else if minutes > 0 {
            return String(format: "%dd %02ds", minutes, secs)
        } else {
            return String(format: "%ds", secs)
        }
    }

    /// Short countdown: "01:23:45" — used in the medium widget.
    static func countdownHMS(to target: Date, from reference: Date = Date()) -> String {
        let seconds = max(Int(target.timeIntervalSince(reference)), 0)
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%02d:%02d", m, s)
    }

    // MARK: - Progress Ring Value

    /// Elapsed fraction (0.0→1.0) through the current prayer window.
    /// Used to drive the circular progress ring angle.
    static func elapsedFraction(
        windowStart: Date,
        windowEnd:   Date,
        at reference: Date = Date()
    ) -> Double {
        let total   = windowEnd.timeIntervalSince(windowStart)
        let elapsed = reference.timeIntervalSince(windowStart)
        guard total > 0 else { return 0 }
        return min(max(elapsed / total, 0), 1)
    }

    // MARK: - Private Helpers

    /// Synthesises a next-day Imsak ~1:15 hours after midnight when we have no
    /// real tomorrow data. This is a graceful fallback only.
    private static func syntheticTomorrowImsak(from yatsi: Prayer) -> Prayer {
        let approxImsak = Calendar.current.date(
            byAdding: .hour, value: 8, to: yatsi.time
        ) ?? yatsi.time.addingTimeInterval(8 * 3600)

        return Prayer(
            id:         0,
            name:       PrayerMetadata.catalogue[0].name,
            arabicName: PrayerMetadata.catalogue[0].arabicName,
            symbol:     PrayerMetadata.catalogue[0].symbol,
            time:       approxImsak
        )
    }

    private static func nextMidnight(after date: Date) -> Date? {
        var components    = Calendar.current.dateComponents([.year, .month, .day], from: date)
        components.day    = (components.day ?? 1) + 1
        components.hour   = 0
        components.minute = 0
        components.second = 0
        return Calendar.current.date(from: components)
    }
}
