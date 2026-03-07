// MARK: - MakamWidget.swift
// Makam — WidgetKit entry: TimelineProvider + Widget definition.
//
// Architecture note:
//   TimelineProvider runs in the widget extension process. Network calls are
//   NOT performed here (WidgetKit has strict time limits). Instead:
//     1. `getSnapshot` reads the shared cache (written by the main app).
//     2. `getTimeline` reads the same cache and builds one TimelineEntry
//        per prayer time so WidgetKit refreshes the display automatically
//        without network round-trips.
//     3. The main app calls `PrayerService.fetchAndCacheToday()` and
//        `WeatherService.fetchAndCache()` on launch to keep both caches fresh.
//        Weather has a 30-minute staleness guard — no redundant network calls.

import WidgetKit
import SwiftUI

// MARK: - Timeline Entry

/// Carries everything the view needs — pre-computed so rendering is instant.
struct MakamEntry: TimelineEntry {
    let date:           Date             // The point in time this entry is valid from
    let prayerContext:  PrayerContext?   // nil → show placeholder/loading state
    let schedule:       DailyPrayerSchedule? // Full day schedule for medium widget list
    let weather:        WeatherSnapshot? // nil → weather chip hidden (not an error)
    let isPlaceholder:  Bool
}

extension MakamEntry {
    /// A static placeholder used during WidgetKit preview / redacted rendering.
    static var placeholder: MakamEntry {
        let now = Date.now

        // Build synthetic prayers 1 hour apart so the placeholder looks realistic
        let fakePrayers: [Prayer] = PrayerMetadata.catalogue.enumerated().map { (i, meta) in
            Prayer(
                id:         i,
                name:       meta.name,
                arabicName: meta.arabicName,
                symbol:     meta.symbol,
                time:       now.addingTimeInterval(Double(i - 2) * 3600)
            )
        }
        let fakeSchedule = DailyPrayerSchedule(date: now, prayers: fakePrayers)
        let context = PrayerCalculator.context(for: fakeSchedule, at: now)
        let fakeWeather = WeatherSnapshot(temperatureCelsius: 18, symbolName: "cloud.sun", fetchedAt: now)
        return MakamEntry(date: now, prayerContext: context, schedule: fakeSchedule, weather: fakeWeather, isPlaceholder: true)
    }
}

// MARK: - Timeline Provider

struct MakamTimelineProvider: TimelineProvider {
    typealias Entry = MakamEntry

    // Called for the WidgetKit gallery & quick-glance preview
    func placeholder(in context: Context) -> MakamEntry {
        .placeholder
    }

    // Called when WidgetKit needs a current snapshot (e.g. widget picker)
    func getSnapshot(in context: Context, completion: @escaping (MakamEntry) -> Void) {
        if let entry = buildCurrentEntry() {
            completion(entry)
        } else {
            completion(.placeholder)
        }
    }

    // Called when WidgetKit builds the full timeline
    func getTimeline(in context: Context, completion: @escaping (Timeline<MakamEntry>) -> Void) {
        guard let schedule = PrayerService.cachedTodaySchedule() else {
            // No cache: show placeholder and ask WidgetKit to retry in 15 min
            let placeholder = MakamEntry(
                date:          .now,
                prayerContext: nil,
                schedule:      nil,
                weather:       nil,
                isPlaceholder: true
            )
            let timeline = Timeline(entries: [placeholder], policy: .after(.now.addingTimeInterval(900)))
            completion(timeline)
            return
        }

        // Build one entry per prayer time for today.
        // Weather is fetched once and shared across all entries — it is ambient
        // context that does not need per-prayer precision.
        let refreshDates = PrayerCalculator.timelineRefreshDates(for: schedule)
        let weather      = WeatherService.cachedWeather()   // nil-safe — widget never networks
        var entries: [MakamEntry] = []

        for refreshDate in refreshDates {
            let ctx = PrayerCalculator.context(for: schedule, at: refreshDate)
            let entry = MakamEntry(
                date:          refreshDate,
                prayerContext: ctx,
                schedule:      schedule,
                weather:       weather,
                isPlaceholder: false
            )
            entries.append(entry)
        }

        // After the last prayer of the day, request a full reload at midnight
        // so the main app has time to fetch tomorrow's data.
        let reloadPolicy: TimelineReloadPolicy
        if let midnight = refreshDates.last {
            reloadPolicy = .after(midnight)
        } else {
            reloadPolicy = .atEnd
        }

        let timeline = Timeline(entries: entries, policy: reloadPolicy)
        completion(timeline)
    }

    // MARK: - Private

    private func buildCurrentEntry() -> MakamEntry? {
        guard let schedule = PrayerService.cachedTodaySchedule() else { return nil }
        let ctx = PrayerCalculator.context(for: schedule, at: .now)
        return MakamEntry(
            date:          .now,
            prayerContext: ctx,
            schedule:      schedule,
            weather:       WeatherService.cachedWeather(),
            isPlaceholder: false
        )
    }
}

// MARK: - Widget Definition

/// The single `Widget` struct that supports three display families:
///   • `.systemSmall`          — circular ring + current prayer + countdown
///   • `.systemMedium`         — ring + full prayer list with current highlighted
///   • `.accessoryRectangular` — lock-screen compact version
struct MakamWidget: Widget {
    static let kind = "MakamWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind:     Self.kind,
            provider: MakamTimelineProvider()
        ) { entry in
            MakamWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Makam")
        .description("Namaz vakitlerini takip et.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .accessoryRectangular   // Lock Screen (iOS 16+)
        ])
    }
}

// MARK: - Entry View Router

/// Routes each widget family to its dedicated view implementation.
/// This struct lives here so `MakamWidget.body` stays clean.
struct MakamWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: MakamEntry

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
                .widgetContainerBackground()

        case .systemMedium:
            MediumWidgetView(entry: entry)
                .widgetContainerBackground()

        case .accessoryRectangular:
            AccessoryRectangularView(entry: entry)
            // Note: ContainerBackground is not used for accessory families

        default:
            SmallWidgetView(entry: entry)
                .widgetContainerBackground()
        }
    }
}

// MARK: - ContainerBackground Helper

/// Applies `containerBackground` on iOS 17+ and falls back to a plain
/// `background` modifier on earlier OS versions — keeping a single code path.
private extension View {
    @ViewBuilder
    func widgetContainerBackground() -> some View {
        if #available(iOS 17.0, *) {
            containerBackground(for: .widget) {
                MakamWidgetBackground()
            }
        } else {
            background(MakamWidgetBackground())
        }
    }
}

// MARK: - Shared Background

/// A near-black background with a very subtle warm undertone — signature Makam palette.
struct MakamWidgetBackground: View {
    var body: some View {
        // Deep charcoal — pairs with the gold/sand accent in views
        Color(red: 0.08, green: 0.08, blue: 0.10)
            .ignoresSafeArea()
    }
}
