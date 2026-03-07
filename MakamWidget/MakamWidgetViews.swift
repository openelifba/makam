// MARK: - MakamWidgetViews.swift
// Makam — All widget display family views.
//
// Design system:
//   • Palette: near-black bg, warm sand (#E8D5B0) text, muted gold ring fill
//   • Type:    SF Pro Rounded throughout — .fontDesign(.rounded) on iOS 16+
//   • Ring:    custom thin arc drawn with a trimmed Circle + stroke
//   • Motion:  no animated transitions (WidgetKit is static per entry)
//   • "Less is more": every label serves a function; nothing decorative.

import SwiftUI
import WidgetKit

// MARK: - Design Tokens

private enum Makam {
    // Colours
    static let sand       = Color(red: 0.910, green: 0.835, blue: 0.690) // #E8D5B0
    static let sandDim    = Color(red: 0.910, green: 0.835, blue: 0.690).opacity(0.45)
    static let gold       = Color(red: 0.780, green: 0.620, blue: 0.340) // #C79E57
    static let goldDim    = Color(red: 0.780, green: 0.620, blue: 0.340).opacity(0.18)
    static let white      = Color.white
    static let bg         = Color(red: 0.08, green: 0.08, blue: 0.10)

    // Tracking (letter-spacing) values mapped to SwiftUI .tracking()
    static let trackingLoose: CGFloat  =  2.5
    static let trackingNormal: CGFloat =  0.8
    static let trackingTight: CGFloat  = -0.3

    // Ring geometry
    static let ringLineWidth: CGFloat  = 3.5
    static let ringStartAngle          = Angle(degrees: -90) // 12 o'clock
}

// MARK: - Shared: Prayer Progress Ring

/// A thin circular arc that sweeps from 0→1 to show elapsed time in the current prayer window.
/// Drawn manually so we own the exact weight and cap style.
struct PrayerProgressRing: View {
    let progress:   Double   // 0.0 → 1.0
    let diameter:   CGFloat
    var lineWidth:  CGFloat = Makam.ringLineWidth

    var body: some View {
        ZStack {
            // Track
            Circle()
                .stroke(Makam.goldDim, lineWidth: lineWidth)
                .frame(width: diameter, height: diameter)

            // Fill
            Circle()
                .trim(from: 0, to: CGFloat(progress))
                .stroke(
                    Makam.gold,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .frame(width: diameter, height: diameter)
                .rotationEffect(Makam.ringStartAngle)
        }
    }
}

// MARK: - Shared: Prayer Name Label

/// The primary prayer name in SF Pro Rounded with tracked capitals.
struct PrayerNameLabel: View {
    let name:     String
    let size:     CGFloat
    var dimmed:   Bool = false

    var body: some View {
        Text(name.uppercased())
            .font(.system(size: size, weight: .semibold, design: .rounded))
            .tracking(Makam.trackingLoose)
            .foregroundStyle(dimmed ? Makam.sandDim : Makam.sand)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }
}

// MARK: - Shared: Countdown Label

/// Displays "01:23" or "1:23:45" in a tight monospaced-width rounded font.
struct CountdownLabel: View {
    let entry:    MakamEntry
    let size:     CGFloat
    var dimmed:   Bool = false

    var body: some View {
        if let ctx = entry.prayerContext {
            Text(timerInterval: entry.date...ctx.countdownDate, countsDown: true)
                .font(.system(size: size, weight: .light, design: .rounded))
                .tracking(Makam.trackingNormal)
                .foregroundStyle(dimmed ? Makam.sandDim : Makam.white.opacity(0.70))
                .monospacedDigit()
                .lineLimit(1)
        } else {
            Text("--:--")
                .font(.system(size: size, weight: .light, design: .rounded))
                .foregroundStyle(Makam.sandDim)
        }
    }
}

// MARK: - SMALL WIDGET

/// Layout: centered ring with prayer name inside, countdown below.
///
/// ┌──────────────────┐
/// │                  │
/// │    ╭───────╮     │
/// │    │ AKŞAM │     │ ← PrayerNameLabel (14pt)
/// │    │ 17:42 │     │ ← time of prayer (10pt)
/// │    ╰───────╯     │ ← PrayerProgressRing
/// │   01:23:45       │ ← CountdownLabel
/// │   Yatsı'ya       │ ← sub-label
/// │                  │
/// └──────────────────┘
struct SmallWidgetView: View {
    let entry: MakamEntry
    private let ringDiameter: CGFloat = 88

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            // Ring + labels inside
            ZStack {
                PrayerProgressRing(
                    progress:  entry.prayerContext?.elapsedFraction() ?? 0,
                    diameter:  ringDiameter
                )

                VStack(spacing: 2) {
                    PrayerNameLabel(
                        name: entry.prayerContext?.current.name ?? "—",
                        size: 13
                    )
                    if let ctx = entry.prayerContext {
                        Text(timeString(ctx.current.time))
                            .font(.system(size: 10, weight: .ultraLight, design: .rounded))
                            .tracking(Makam.trackingNormal)
                            .foregroundStyle(Makam.sandDim)
                    }
                }
            }
            .frame(width: ringDiameter, height: ringDiameter)

            Spacer().frame(height: 10)

            // Countdown
            CountdownLabel(entry: entry, size: 22)

            Spacer().frame(height: 3)

            // Sub-label: "→ Yatsı'ya"
            if let ctx = entry.prayerContext {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 8, weight: .light))
                        .foregroundStyle(Makam.sandDim)
                    Text(ctx.next.name)
                        .font(.system(size: 10, weight: .regular, design: .rounded))
                        .tracking(Makam.trackingNormal)
                        .foregroundStyle(Makam.sandDim)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - MEDIUM WIDGET

/// Layout: ring on the left (small), full prayer list on the right.
///
/// ┌────────────────────────────────────────┐
/// │  ╭───╮   İmsak    05:23               │
/// │  │   │ ● AKŞAM   17:42  ← active     │
/// │  ╰───╯   Yatsı   19:05               │
/// │  01:23   Yatsı'ya kadar               │
/// └────────────────────────────────────────┘
struct MediumWidgetView: View {
    let entry: MakamEntry
    private let ringDiameter: CGFloat = 56

    var body: some View {
        HStack(alignment: .center, spacing: 16) {

            // Left: ring + countdown
            VStack(spacing: 6) {
                ZStack {
                    PrayerProgressRing(
                        progress:  entry.prayerContext?.elapsedFraction() ?? 0,
                        diameter:  ringDiameter,
                        lineWidth: 3
                    )
                    if let ctx = entry.prayerContext {
                        Image(systemName: ctx.current.symbol)
                            .font(.system(size: 14, weight: .ultraLight))
                            .foregroundStyle(Makam.gold)
                    }
                }

                CountdownLabel(entry: entry, size: 14)
                    .frame(maxWidth: ringDiameter + 8)
                    .multilineTextAlignment(.center)

                if let ctx = entry.prayerContext {
                    Text(ctx.next.name)
                        .font(.system(size: 9, weight: .regular, design: .rounded))
                        .tracking(Makam.trackingNormal)
                        .foregroundStyle(Makam.sandDim)
                }
            }
            .frame(width: ringDiameter + 8)

            // Divider
            Rectangle()
                .fill(Makam.goldDim)
                .frame(width: 0.5)
                .padding(.vertical, 8)

            // Right: prayer time list
            VStack(alignment: .leading, spacing: 4) {
                if let schedule = entry.schedule {
                    ForEach(schedule.prayers) { prayer in
                        PrayerRowView(
                            prayer:   prayer,
                            isActive: prayer.id == entry.prayerContext?.current.id
                        )
                    }
                } else {
                    ForEach(0..<6) { _ in
                        PrayerRowPlaceholder()
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: Prayer Row (used in medium widget)

private struct PrayerRowView: View {
    let prayer:   Prayer
    let isActive: Bool

    var body: some View {
        HStack(spacing: 6) {
            // Active indicator dot
            Circle()
                .fill(isActive ? Makam.gold : Color.clear)
                .frame(width: 4, height: 4)

            Text(prayer.name)
                .font(.system(size: isActive ? 11 : 10,
                              weight: isActive ? .semibold : .light,
                              design: .rounded))
                .tracking(isActive ? Makam.trackingLoose : Makam.trackingNormal)
                .foregroundStyle(isActive ? Makam.sand : Makam.sandDim)
                .lineLimit(1)

            Spacer()

            Text(timeString(prayer.time))
                .font(.system(size: 10, weight: isActive ? .medium : .ultraLight, design: .rounded))
                .tracking(Makam.trackingNormal)
                .foregroundStyle(isActive ? Makam.sand : Makam.sandDim)
                .monospacedDigit()
        }
    }
}

private struct PrayerRowPlaceholder: View {
    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(Color.clear).frame(width: 4, height: 4)
            RoundedRectangle(cornerRadius: 2)
                .fill(Makam.goldDim)
                .frame(width: 40, height: 8)
            Spacer()
            RoundedRectangle(cornerRadius: 2)
                .fill(Makam.goldDim)
                .frame(width: 30, height: 8)
        }
        .redacted(reason: .placeholder)
    }
}

// MARK: - ACCESSORY RECTANGULAR (Lock Screen)

/// Lock-screen widget — monochrome, minimal.
/// WidgetKit renders accessory families with vibrancy on the lock screen.
///
/// ┌─────────────────────────────┐
/// │ ◐  AKŞAM  →  01:23:45      │
/// └─────────────────────────────┘
struct AccessoryRectangularView: View {
    let entry: MakamEntry

    var body: some View {
        HStack(spacing: 8) {
            // Compact ring (accessory size)
            if let ctx = entry.prayerContext {
                ZStack {
                    Circle()
                        .trim(from: 0, to: CGFloat(ctx.elapsedFraction()))
                        .stroke(style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                        .rotationEffect(Makam.ringStartAngle)
                        .frame(width: 18, height: 18)

                    Image(systemName: ctx.current.symbol)
                        .font(.system(size: 8, weight: .light))
                }
            } else {
                Circle()
                    .stroke(style: StrokeStyle(lineWidth: 2))
                    .frame(width: 18, height: 18)
                    .opacity(0.4)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text((entry.prayerContext?.current.name ?? "—").uppercased())
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .tracking(Makam.trackingLoose)
                    .lineLimit(1)

                CountdownLabel(entry: entry, size: 11)
            }

            Spacer()
        }
        .padding(.horizontal, 4)
    }
}

// MARK: - Utility

private func timeString(_ date: Date) -> String {
    let fmt          = DateFormatter()
    fmt.dateFormat   = "HH:mm"
    fmt.locale       = Locale(identifier: "tr_TR")
    return fmt.string(from: date)
}

// MARK: - Xcode Previews

#if DEBUG
struct MakamWidgetViews_Previews: PreviewProvider {
    static var entry: MakamEntry { .placeholder }

    static var previews: some View {
        Group {
            SmallWidgetView(entry: entry)
                .previewContext(WidgetPreviewContext(family: .systemSmall))
                .previewDisplayName("Small")

            MediumWidgetView(entry: entry)
                .previewContext(WidgetPreviewContext(family: .systemMedium))
                .previewDisplayName("Medium")

            AccessoryRectangularView(entry: entry)
                .previewContext(WidgetPreviewContext(family: .accessoryRectangular))
                .previewDisplayName("Lock Screen")
        }
        .environment(\.colorScheme, .dark)
    }
}
#endif
