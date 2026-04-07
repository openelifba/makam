// MARK: - MakamWidget.swift
// Makam — WidgetKit extension: small + medium prayer-times home-screen widgets.

import WidgetKit
import SwiftUI

// MARK: - App Group

private let appGroupID = "group.com.yaysoftwares.makam"

private extension UserDefaults {
    static var shared: UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }
    var widgetDistrictId: String?   { string(forKey: "makam.selectedDistrictId") }
    var widgetDistrictName: String? { string(forKey: "makam.selectedDistrictName") }
}

// MARK: - Design Tokens (widget-local copy)

private enum W {
    static let bg       = Color(red: 0.08, green: 0.08, blue: 0.10)
    static let gold     = Color(red: 0.780, green: 0.620, blue: 0.340)
    static let goldDim  = Color(red: 0.780, green: 0.620, blue: 0.340).opacity(0.18)
    static let sand     = Color(red: 0.910, green: 0.835, blue: 0.690)
    static let sandDim  = Color(red: 0.910, green: 0.835, blue: 0.690).opacity(0.45)
    static let white    = Color.white
}

// MARK: - Timeline Entry

struct PrayerWidgetEntry: TimelineEntry {
    let date:         Date
    let schedule:     DailyPrayerSchedule?
    let context:      PrayerContext?
    let locationName: String
}

// MARK: - Timeline Provider

struct PrayerTimelineProvider: TimelineProvider {
    typealias Entry = PrayerWidgetEntry

    func placeholder(in context: Context) -> PrayerWidgetEntry {
        PrayerWidgetEntry(date: Date(), schedule: nil, context: nil, locationName: "İstanbul")
    }

    func getSnapshot(in context: Context, completion: @escaping (PrayerWidgetEntry) -> Void) {
        Task { completion(await buildEntry(for: Date())) }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PrayerWidgetEntry>) -> Void) {
        Task {
            let now = Date()
            guard let schedule = await fetchSchedule() else {
                // No data: retry in 1 hour
                let fallback = PrayerWidgetEntry(date: now, schedule: nil, context: nil, locationName: locationLabel())
                let retry = Calendar.current.date(byAdding: .hour, value: 1, to: now) ?? now
                completion(Timeline(entries: [fallback], policy: .after(retry)))
                return
            }

            // One entry per prayer-window boundary so the current/next card updates.
            let refreshDates = PrayerCalculator.timelineRefreshDates(for: schedule)
            let futureDates  = ([now] + refreshDates).filter { $0 >= now }

            var entries: [PrayerWidgetEntry] = []
            for d in futureDates {
                let ctx = PrayerCalculator.context(for: schedule, at: d)
                entries.append(PrayerWidgetEntry(date: d, schedule: schedule, context: ctx, locationName: locationLabel()))
            }

            // Reload after midnight for fresh data
            let midnight = nextMidnight()
            completion(Timeline(entries: entries, policy: .after(midnight)))
        }
    }

    // MARK: - Helpers

    private func fetchSchedule() async -> DailyPrayerSchedule? {
        // Read from shared App Group suite → main app standard → hardcoded Istanbul default
        let districtId = UserDefaults.shared.widgetDistrictId
                      ?? UserDefaults.standard.string(forKey: "makam.selectedDistrictId")
                      ?? "9541"   // İstanbul fallback
        guard let vakit = try? await EzanVaktiService.fetchTodayPrayerTimes(districtId: districtId) else { return nil }
        return EzanVaktiService.toDailySchedule(from: vakit)
    }

    private func buildEntry(for date: Date) async -> PrayerWidgetEntry {
        let schedule = await fetchSchedule()
        let ctx = schedule.flatMap { PrayerCalculator.context(for: $0, at: date) }
        return PrayerWidgetEntry(date: date, schedule: schedule, context: ctx, locationName: locationLabel())
    }

    private func locationLabel() -> String {
        if let name = UserDefaults.shared.widgetDistrictName, !name.isEmpty { return name }
        if let name = UserDefaults.standard.string(forKey: "makam.selectedDistrictName"), !name.isEmpty { return name }
        return "İstanbul"   // default matches the 9541 fallback district
    }

    private func nextMidnight() -> Date {
        let cal  = Calendar.current
        let next = cal.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        return cal.startOfDay(for: next)
    }
}

// MARK: - Shared time formatting helper

private func hhmm(_ date: Date) -> String {
    let f = DateFormatter(); f.dateFormat = "HH:mm"; return f.string(from: date)
}

// MARK: - Small Widget View

struct SmallWidgetView: View {
    let entry: PrayerWidgetEntry

    var body: some View {
        ZStack {
            W.bg.ignoresSafeArea()
            VStack(spacing: 0) {
                // Location
                HStack(spacing: 3) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(W.gold)
                    Text(entry.locationName)
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .foregroundStyle(W.sandDim)
                        .lineLimit(1)
                }
                .padding(.bottom, 6)

                if let ctx = entry.context {
                    // Current prayer
                    HStack(spacing: 4) {
                        Image(systemName: ctx.current.symbol)
                            .font(.system(size: 11, weight: .light))
                            .foregroundStyle(W.gold)
                        Text(ctx.current.name.uppercased())
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .tracking(1.5)
                            .foregroundStyle(W.sand)
                        Spacer()
                        Text(hhmm(ctx.current.time))
                            .font(.system(size: 11, weight: .light, design: .monospaced))
                            .foregroundStyle(W.sandDim)
                    }
                    .padding(.bottom, 4)

                    // Countdown — dominant element
                    Text(ctx.next.time, style: .timer)
                        .font(.system(size: 34, weight: .semibold, design: .monospaced))
                        .foregroundStyle(W.white)
                        .monospacedDigit()
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)

                    // Divider
                    Rectangle()
                        .fill(W.gold.opacity(0.25))
                        .frame(height: 0.5)
                        .padding(.vertical, 4)

                    // Next prayer label
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.right")
                            .font(.system(size: 8))
                        Text(ctx.next.name.uppercased())
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .tracking(1)
                        Spacer()
                        Text(hhmm(ctx.next.time))
                            .font(.system(size: 10, weight: .light, design: .monospaced))
                    }
                    .foregroundStyle(W.sandDim)
                } else {
                    // Placeholder / no data
                    Image(systemName: "moon.stars")
                        .font(.system(size: 24, weight: .light))
                        .foregroundStyle(W.gold.opacity(0.5))
                    Text("—")
                        .font(.system(size: 12))
                        .foregroundStyle(W.sandDim)
                }
            }
            .padding(12)
        }
    }
}

// MARK: - Medium Widget View

struct MediumWidgetView: View {
    let entry: PrayerWidgetEntry

    var body: some View {
        ZStack {
            W.bg.ignoresSafeArea()
            HStack(spacing: 0) {
                // Left: active prayer card
                leftCard
                    .frame(maxWidth: .infinity)

                Rectangle()
                    .fill(W.gold.opacity(0.15))
                    .frame(width: 0.5)
                    .padding(.vertical, 12)

                // Right: full prayer list
                if let schedule = entry.schedule {
                    prayerList(schedule: schedule)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 8)
        }
    }

    private var leftCard: some View {
        VStack(spacing: 4) {
            // Location
            HStack(spacing: 3) {
                Image(systemName: "location.fill")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(W.gold)
                Text(entry.locationName)
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundStyle(W.sandDim)
                    .lineLimit(1)
            }

            if let ctx = entry.context {
                Spacer(minLength: 2)

                // Current prayer
                Image(systemName: ctx.current.symbol)
                    .font(.system(size: 22, weight: .light))
                    .foregroundStyle(W.gold)

                Text(ctx.current.name.uppercased())
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .tracking(1.5)
                    .foregroundStyle(W.sand)

                Text(hhmm(ctx.current.time))
                    .font(.system(size: 10, weight: .light, design: .monospaced))
                    .foregroundStyle(W.sandDim)

                Spacer(minLength: 4)

                // Countdown — dominant element
                Text(ctx.next.time, style: .timer)
                    .font(.system(size: 28, weight: .semibold, design: .monospaced))
                    .foregroundStyle(W.white)
                    .monospacedDigit()
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)

                HStack(spacing: 3) {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 7))
                    Text(ctx.next.name.uppercased())
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .tracking(0.8)
                }
                .foregroundStyle(W.sandDim)

                Spacer(minLength: 2)
            } else {
                Spacer()
                Image(systemName: "moon.stars")
                    .font(.system(size: 24))
                    .foregroundStyle(W.gold.opacity(0.4))
                Spacer()
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 4)
    }

    private func prayerList(schedule: DailyPrayerSchedule) -> some View {
        VStack(spacing: 3) {
            ForEach(schedule.prayers) { prayer in
                let isCurrent = entry.context?.current.id == prayer.id
                HStack(spacing: 5) {
                    Image(systemName: prayer.symbol)
                        .font(.system(size: 10, weight: .light))
                        .frame(width: 14)
                        .foregroundStyle(isCurrent ? W.gold : W.sandDim)

                    Text(prayer.name)
                        .font(.system(size: 11, weight: isCurrent ? .semibold : .regular, design: .rounded))
                        .foregroundStyle(isCurrent ? W.sand : W.sandDim)

                    Spacer()

                    Text(hhmm(prayer.time))
                        .font(.system(size: 11, weight: .light, design: .monospaced))
                        .foregroundStyle(isCurrent ? W.white : W.white.opacity(0.45))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isCurrent ? W.goldDim : Color.clear)
                )
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 4)
    }
}

// MARK: - Widget Entry View (size router)

struct MakamWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: PrayerWidgetEntry

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        default:
            MediumWidgetView(entry: entry)
        }
    }
}

// MARK: - Widget Definition

struct MakamPrayerWidget: Widget {
    let kind = "MakamPrayerWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PrayerTimelineProvider()) { entry in
            MakamWidgetEntryView(entry: entry)
                .modifier(WidgetBackgroundModifier())
        }
        .configurationDisplayName("Namaz Vakitleri")
        .description("Bir sonraki namaz vaktini ve günün tüm vakitlerini gösterir.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Compatibility Modifiers

private struct WidgetBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 17, *) {
            content.containerBackground(W.bg, for: .widget)
        } else {
            content.background(W.bg)
        }
    }
}

// MARK: - Widget Bundle

@main
struct MakamWidgetBundle: WidgetBundle {
    var body: some Widget {
        MakamPrayerWidget()
    }
}
