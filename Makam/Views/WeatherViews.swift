// MARK: - WeatherViews.swift
// Makam — Weather widget components: inline header chip and detail half-sheet.
//
// Design intent:
//   • WeatherChip sits below the city name in the header, rendered at 11pt with
//     reduced opacity so it reads as ambient context, not primary content.
//   • WeatherDetailSheet is a half-sheet (.fraction(0.45)) — not full-screen —
//     so prayer times remain partially visible, reinforcing their hierarchy.
//   • The sheet's signature feature: sunrise/sunset times from the weather API
//     are correlated with the Güneş and Akşam prayer rows, giving the user a
//     prayer-relevant reason to open the sheet.

import SwiftUI

// MARK: - WeatherChip

/// Compact inline weather display for the header zone.
/// Renders at ambient opacity — meant to be registered passively, not read actively.
struct WeatherChip: View {
    let state: WeatherState
    @Binding var showSheet: Bool

    var body: some View {
        switch state {
        case .idle:
            EmptyView()

        case .loading:
            // Skeleton placeholder that matches the app's loading idiom
            RoundedRectangle(cornerRadius: 3)
                .fill(Makam.goldDim)
                .frame(width: 88, height: 11)
                .padding(.top, 1)

        case .loaded(let snapshot):
            chipContent(snapshot)
                .transition(.opacity.animation(.easeIn(duration: 0.3)))

        case .failed:
            // Silent failure — weather is non-critical, show nothing
            EmptyView()
        }
    }

    private func chipContent(_ weather: WeatherSnapshot) -> some View {
        HStack(spacing: 4) {
            Image(systemName: weather.sfSymbol)
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(Makam.sand)

            Text("\(weather.temperature)°")
                .font(.system(size: 14, weight: .regular, design: .rounded))
                .foregroundColor(Makam.sand)

            Text("·")
                .font(.system(size: 12))
                .foregroundColor(Makam.sandDim)

            Text(weather.shortCondition)
                .font(.system(size: 14, weight: .regular, design: .rounded))
                .foregroundColor(Makam.sand.opacity(0.80))
                .lineLimit(1)
        }
        // Expand tap area to 44pt height for accessibility without visual change
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .onTapGesture { showSheet = true }
    }
}

// MARK: - WeatherDetailSheet

/// Half-sheet detail view presented on WeatherChip tap.
/// Uses .presentationDetents([.fraction(0.45)]) — never full-screen.
struct WeatherDetailSheet: View {
    let snapshot: WeatherSnapshot
    let schedule: DailyPrayerSchedule?

    var body: some View {
        ZStack {
            Makam.bg.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                dragHandle
                    .padding(.bottom, 20)

                temperatureSection
                    .padding(.horizontal, 24)
                    .padding(.bottom, 20)

                statsRow
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)

                Divider()
                    .overlay(Makam.sandDim.opacity(0.15))
                    .padding(.horizontal, 24)
                    .padding(.bottom, 20)

                if let schedule = schedule {
                    sunCorrelationSection(schedule: schedule)
                        .padding(.horizontal, 24)
                }

                Spacer()
            }
            .padding(.top, 14)
        }
    }

    // MARK: Sub-views

    private var dragHandle: some View {
        HStack {
            Spacer()
            RoundedRectangle(cornerRadius: 2)
                .fill(Makam.sandDim.opacity(0.3))
                .frame(width: 36, height: 4)
            Spacer()
        }
    }

    private var temperatureSection: some View {
        HStack(alignment: .center, spacing: 16) {
            Image(systemName: snapshot.sfSymbol)
                .font(.system(size: 40, weight: .ultraLight))
                .foregroundColor(Makam.gold.opacity(0.65))

            VStack(alignment: .leading, spacing: 2) {
                Text("\(snapshot.temperature)°")
                    .font(.system(size: 52, weight: .ultraLight, design: .rounded))
                    .foregroundColor(Makam.sand)

                Text(snapshot.shortCondition)
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundColor(Makam.sandDim)
            }

            Spacer()
        }
    }

    private var statsRow: some View {
        HStack(spacing: 0) {
            statItem(label: "Hissedilen", value: "\(snapshot.feelsLike)°")

            statDivider

            statItem(label: "Nem", value: "%\(snapshot.humidity)")

            statDivider

            statItem(label: "Rüzgar", value: "\(snapshot.windSpeed) km/s")
        }
    }

    private func statItem(label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 16, weight: .regular, design: .rounded))
                .foregroundColor(Makam.sand)
            Text(label)
                .font(.system(size: 11, weight: .regular, design: .rounded))
                .foregroundColor(Makam.sandDim)
        }
        .frame(maxWidth: .infinity)
    }

    private var statDivider: some View {
        Rectangle()
            .fill(Makam.sandDim.opacity(0.2))
            .frame(width: 1, height: 32)
    }

    private func sunCorrelationSection(schedule: DailyPrayerSchedule) -> some View {
        VStack(spacing: 14) {
            sunRow(
                symbol:      "sunrise.fill",
                eventLabel:  "Güneş Doğuşu",
                eventTime:   snapshot.sunrise,
                prayer:      schedule.gunes
            )
            sunRow(
                symbol:      "sunset.fill",
                eventLabel:  "Güneş Batışı",
                eventTime:   snapshot.sunset,
                prayer:      schedule.aksam
            )
        }
    }

    /// Renders one correlation row: astronomical event (left) vs. prayer time (right).
    private func sunRow(
        symbol:     String,
        eventLabel: String,
        eventTime:  Date,
        prayer:     Prayer
    ) -> some View {
        HStack {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .light))
                .foregroundColor(Makam.gold.opacity(0.65))
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(eventLabel)
                    .font(.system(size: 11, weight: .regular, design: .rounded))
                    .foregroundColor(Makam.sandDim)
                Text(timeString(eventTime))
                    .font(.system(size: 15, weight: .light, design: .monospaced))
                    .foregroundColor(Makam.sand)
            }

            Spacer()

            // Correlated prayer on the right — gold to tie back to the main UI
            VStack(alignment: .trailing, spacing: 2) {
                Text(prayer.name)
                    .font(.system(size: 11, weight: .regular, design: .rounded))
                    .foregroundColor(Makam.sandDim)
                Text(timeString(prayer.time))
                    .font(.system(size: 15, weight: .light, design: .monospaced))
                    .foregroundColor(Makam.gold)
            }
        }
    }

    // MARK: Helpers

    private func timeString(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"
        return fmt.string(from: date)
    }
}
