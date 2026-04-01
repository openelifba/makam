// MARK: - DynamicBackground.swift
// Makam — Time-based, weather-aware animated gradient background system.
//
// Architecture overview:
//
//   PrayerPeriod       — maps prayer index (0–5) to a named sky time-of-day period
//   WeatherMood        — classifies a WeatherSnapshot into 6 distinct sky moods
//   BackgroundPalette  — typed wrapper for a LinearGradient Color-stop array
//   PaletteLibrary     — static catalogue of 36 hand-tuned palettes (6×6 matrix)
//   IslamicPatternOverlay — Canvas-drawn repeating 8-pointed star grid (7% opacity, .overlay blend)
//   DynamicPrayerBackground — animated crossfade view; drop into any ZStack as a background layer
//
// Usage:
//   ZStack {
//       DynamicPrayerBackground(
//           prayerID:     viewModel.context?.current.id,
//           weatherState: viewModel.weatherState
//       )
//       // … your content
//   }

import SwiftUI

// MARK: - Prayer Period

/// Maps the active prayer's numeric id to a named sky period.
/// Order matches PrayerMetadata.catalogue: 0 = İmsak … 5 = Yatsı.
enum PrayerPeriod: Int, CaseIterable, Equatable {
    case fajr    = 0   // Pre-dawn  (~03:30–05:00)
    case shuruq  = 1   // Sunrise   (~05:00–07:00)
    case dhuhr   = 2   // Midday    (~12:00–15:00)
    case asr     = 3   // Afternoon (~15:00–18:00)
    case maghrib = 4   // Sunset    (~18:00–20:00)
    case isha    = 5   // Night     (~20:00–03:30)

    init(prayerID: Int) {
        self = PrayerPeriod(rawValue: prayerID) ?? .isha
    }
}

// MARK: - Weather Mood

/// Six sky moods derived from the Open-Meteo WMO code (accessed via WeatherSnapshot.sfSymbol).
/// Fewer categories than raw WMO codes — subtle rain/drizzle distinctions don't meaningfully
/// alter the visual sky palette from a UI perspective.
enum WeatherMood: Equatable {
    case clear          // Codes 0–1:   clear sky, strong direct sun
    case partlyCloudy   // Code 2:      scattered clouds, sun still visible
    case overcast       // Codes 3, 45, 48: thick cloud cover or fog
    case precipitation  // Codes 51–82: drizzle, rain, sleet
    case snow           // Codes 71–77, 85–86: snowfall
    case storm          // Codes 95–99: thunderstorms

    /// Derives mood from the `sfSymbol` string stored on `WeatherSnapshot`.
    init(sfSymbol: String) {
        switch sfSymbol {
        case "sun.max.fill":
            self = .clear
        case "cloud.sun.fill":
            self = .partlyCloudy
        case let s where s.contains("bolt"):
            self = .storm
        case let s where s.contains("snow"):
            self = .snow
        case let s where s.contains("rain") || s.contains("drizzle")
                      || s.contains("sleet") || s.contains("heavyrain"):
            self = .precipitation
        case let s where s.contains("fog") || s.contains("cloud"):
            self = .overcast
        default:
            self = .clear
        }
    }

    /// Convenience: derive mood directly from a `WeatherState` enum value.
    static func from(_ state: WeatherState) -> WeatherMood {
        if case .loaded(let snap) = state {
            return WeatherMood(sfSymbol: snap.sfSymbol)
        }
        return .clear
    }
}

// MARK: - Background Palette

/// A typed wrapper around a LinearGradient Color-stop array.
/// All palettes flow top (zenith) → bottom (horizon).
struct BackgroundPalette: Equatable {
    let stops: [Color]
}

// MARK: - Palette Library

/// Central, static catalogue of all 36 background palettes.
///
/// Design rules applied to every palette:
///   • White foreground text must remain legible — max luminosity ~65%.
///   • Sky accuracy: colors reference real photographic sky references.
///   • Warm/cool split: warm tones for dawn/dusk periods; cool tones for night/rain.
///   • Weather modulation: overcast/rain/snow desaturate and darken; storm is the darkest.
enum PaletteLibrary {

    static func palette(for period: PrayerPeriod, mood: WeatherMood) -> BackgroundPalette {
        switch (period, mood) {

        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        // İMSAK — Pre-dawn: stars fading, deep blues/indigo
        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

        case (.fajr, .clear):
            // Cosmos near-black → deep indigo → midnight violet
            return .init(stops: [
                Color(red: 0.04, green: 0.03, blue: 0.15),
                Color(red: 0.08, green: 0.06, blue: 0.28),
                Color(red: 0.15, green: 0.09, blue: 0.38),
            ])

        case (.fajr, .partlyCloudy):
            // Stars dimmed by thin cloud — bluer, slightly lighter
            return .init(stops: [
                Color(red: 0.05, green: 0.05, blue: 0.18),
                Color(red: 0.10, green: 0.09, blue: 0.28),
                Color(red: 0.17, green: 0.13, blue: 0.34),
            ])

        case (.fajr, .overcast):
            // Thick cloud blocks starlight — flat charcoal-navy
            return .init(stops: [
                Color(red: 0.07, green: 0.07, blue: 0.12),
                Color(red: 0.11, green: 0.10, blue: 0.17),
                Color(red: 0.15, green: 0.14, blue: 0.21),
            ])

        case (.fajr, .precipitation):
            // Rain-soaked pre-dawn — cool blue-slate
            return .init(stops: [
                Color(red: 0.05, green: 0.07, blue: 0.17),
                Color(red: 0.08, green: 0.11, blue: 0.23),
                Color(red: 0.11, green: 0.15, blue: 0.29),
            ])

        case (.fajr, .snow):
            // Snowy pre-dawn — diffused ambient cold light, blue-silver
            return .init(stops: [
                Color(red: 0.07, green: 0.09, blue: 0.21),
                Color(red: 0.12, green: 0.14, blue: 0.27),
                Color(red: 0.18, green: 0.20, blue: 0.33),
            ])

        case (.fajr, .storm):
            // Approaching storm — almost black, bruised purple undertone
            return .init(stops: [
                Color(red: 0.04, green: 0.02, blue: 0.10),
                Color(red: 0.07, green: 0.04, blue: 0.16),
                Color(red: 0.12, green: 0.07, blue: 0.22),
            ])

        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        // GÜNEŞ — Sunrise: warm pinks, rose, burnt orange rising
        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

        case (.shuruq, .clear):
            // Violet zenith → rich rose-crimson → burnt orange → golden horizon
            return .init(stops: [
                Color(red: 0.11, green: 0.07, blue: 0.22),
                Color(red: 0.46, green: 0.15, blue: 0.26),
                Color(red: 0.82, green: 0.40, blue: 0.12),
                Color(red: 0.96, green: 0.74, blue: 0.34),
            ])

        case (.shuruq, .partlyCloudy):
            // Clouds diffuse the orange into soft peachy-rose
            return .init(stops: [
                Color(red: 0.14, green: 0.10, blue: 0.26),
                Color(red: 0.52, green: 0.26, blue: 0.30),
                Color(red: 0.78, green: 0.50, blue: 0.36),
                Color(red: 0.90, green: 0.72, blue: 0.52),
            ])

        case (.shuruq, .overcast):
            // Thick cloud — muted mauve and warm grey, no orange break-through
            return .init(stops: [
                Color(red: 0.18, green: 0.15, blue: 0.24),
                Color(red: 0.36, green: 0.30, blue: 0.34),
                Color(red: 0.50, green: 0.44, blue: 0.42),
            ])

        case (.shuruq, .precipitation):
            // Rainy dawn — cool blue-grey, warm tones washed out
            return .init(stops: [
                Color(red: 0.10, green: 0.12, blue: 0.25),
                Color(red: 0.20, green: 0.22, blue: 0.37),
                Color(red: 0.32, green: 0.34, blue: 0.49),
            ])

        case (.shuruq, .snow):
            // Snowy sunrise — pale steel-blue with a faint warm horizon blush
            return .init(stops: [
                Color(red: 0.14, green: 0.16, blue: 0.31),
                Color(red: 0.38, green: 0.42, blue: 0.55),
                Color(red: 0.60, green: 0.58, blue: 0.63),
            ])

        case (.shuruq, .storm):
            // Stormy dawn — ominous dark purples, only a thin ember slit at horizon
            return .init(stops: [
                Color(red: 0.06, green: 0.04, blue: 0.14),
                Color(red: 0.18, green: 0.10, blue: 0.20),
                Color(red: 0.36, green: 0.24, blue: 0.16),
            ])

        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        // ÖĞLE — Midday: high sun, saturated azure sky
        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

        case (.dhuhr, .clear):
            // Deep azure zenith → rich mid-blue → lighter horizon cerulean
            return .init(stops: [
                Color(red: 0.04, green: 0.22, blue: 0.52),
                Color(red: 0.06, green: 0.36, blue: 0.72),
                Color(red: 0.14, green: 0.50, blue: 0.84),
            ])

        case (.dhuhr, .partlyCloudy):
            // Blue sky with hazy patches — lighter, slightly desaturated
            return .init(stops: [
                Color(red: 0.08, green: 0.24, blue: 0.52),
                Color(red: 0.18, green: 0.38, blue: 0.64),
                Color(red: 0.36, green: 0.54, blue: 0.74),
            ])

        case (.dhuhr, .overcast):
            // Flat diffuse canopy — grey-blue, no visible sun
            return .init(stops: [
                Color(red: 0.22, green: 0.24, blue: 0.30),
                Color(red: 0.32, green: 0.34, blue: 0.40),
                Color(red: 0.42, green: 0.44, blue: 0.50),
            ])

        case (.dhuhr, .precipitation):
            // Rainy noon — uniform blue-slate
            return .init(stops: [
                Color(red: 0.12, green: 0.18, blue: 0.34),
                Color(red: 0.18, green: 0.26, blue: 0.44),
                Color(red: 0.24, green: 0.34, blue: 0.52),
            ])

        case (.dhuhr, .snow):
            // Snowy midday — milky, bright blue-grey canopy
            return .init(stops: [
                Color(red: 0.30, green: 0.34, blue: 0.46),
                Color(red: 0.44, green: 0.48, blue: 0.58),
                Color(red: 0.58, green: 0.60, blue: 0.68),
            ])

        case (.dhuhr, .storm):
            // Stormy noon — dark threatening navy, sun fully blocked
            return .init(stops: [
                Color(red: 0.08, green: 0.10, blue: 0.20),
                Color(red: 0.14, green: 0.16, blue: 0.28),
                Color(red: 0.20, green: 0.22, blue: 0.36),
            ])

        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        // İKİNDİ — Afternoon: warm amber light, sun dropping in the west
        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

        case (.asr, .clear):
            // Teal-blue zenith → warm amber → liquid gold horizon
            return .init(stops: [
                Color(red: 0.06, green: 0.20, blue: 0.46),
                Color(red: 0.38, green: 0.26, blue: 0.10),
                Color(red: 0.84, green: 0.56, blue: 0.10),
                Color(red: 0.96, green: 0.80, blue: 0.44),
            ])

        case (.asr, .partlyCloudy):
            // Warm amber sky, clouds scattering the gold
            return .init(stops: [
                Color(red: 0.10, green: 0.22, blue: 0.46),
                Color(red: 0.46, green: 0.36, blue: 0.18),
                Color(red: 0.76, green: 0.60, blue: 0.30),
            ])

        case (.asr, .overcast):
            // Warm grey-brown, afternoon light filtered through cloud
            return .init(stops: [
                Color(red: 0.18, green: 0.18, blue: 0.24),
                Color(red: 0.30, green: 0.28, blue: 0.26),
                Color(red: 0.44, green: 0.40, blue: 0.34),
            ])

        case (.asr, .precipitation):
            // Afternoon rain — cool blue-charcoal, gold stripped away
            return .init(stops: [
                Color(red: 0.10, green: 0.14, blue: 0.28),
                Color(red: 0.20, green: 0.22, blue: 0.38),
                Color(red: 0.30, green: 0.30, blue: 0.45),
            ])

        case (.asr, .snow):
            // Cold afternoon snow — silvery blue-grey
            return .init(stops: [
                Color(red: 0.20, green: 0.24, blue: 0.40),
                Color(red: 0.38, green: 0.42, blue: 0.54),
                Color(red: 0.56, green: 0.58, blue: 0.66),
            ])

        case (.asr, .storm):
            // Stormy afternoon — dark amber-charcoal
            return .init(stops: [
                Color(red: 0.08, green: 0.08, blue: 0.14),
                Color(red: 0.18, green: 0.14, blue: 0.16),
                Color(red: 0.28, green: 0.22, blue: 0.20),
            ])

        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        // AKŞAM — Sunset (Maghrib): dramatic warm palette
        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

        case (.maghrib, .clear):
            // Deep violet zenith → rich crimson → burning orange → amber horizon
            return .init(stops: [
                Color(red: 0.08, green: 0.04, blue: 0.20),
                Color(red: 0.52, green: 0.10, blue: 0.22),
                Color(red: 0.84, green: 0.28, blue: 0.08),
                Color(red: 0.96, green: 0.56, blue: 0.12),
            ])

        case (.maghrib, .partlyCloudy):
            // Clouds catching the last light — peachy-pink, softer orange
            return .init(stops: [
                Color(red: 0.12, green: 0.08, blue: 0.26),
                Color(red: 0.56, green: 0.22, blue: 0.28),
                Color(red: 0.80, green: 0.44, blue: 0.24),
                Color(red: 0.90, green: 0.64, blue: 0.38),
            ])

        case (.maghrib, .overcast):
            // Cloudy sunset — muted rust, warm grey, glow suppressed
            return .init(stops: [
                Color(red: 0.14, green: 0.10, blue: 0.20),
                Color(red: 0.32, green: 0.22, blue: 0.22),
                Color(red: 0.50, green: 0.36, blue: 0.28),
            ])

        case (.maghrib, .precipitation):
            // Rainy sunset — cool purple-grey, no warm glow reaches through
            return .init(stops: [
                Color(red: 0.08, green: 0.10, blue: 0.24),
                Color(red: 0.18, green: 0.18, blue: 0.36),
                Color(red: 0.30, green: 0.26, blue: 0.44),
            ])

        case (.maghrib, .snow):
            // Snowy sunset — cold blush-lavender
            return .init(stops: [
                Color(red: 0.14, green: 0.14, blue: 0.30),
                Color(red: 0.36, green: 0.30, blue: 0.48),
                Color(red: 0.54, green: 0.48, blue: 0.60),
            ])

        case (.maghrib, .storm):
            // Stormy sunset — near-black with deep crimson bruise
            return .init(stops: [
                Color(red: 0.05, green: 0.03, blue: 0.12),
                Color(red: 0.16, green: 0.07, blue: 0.18),
                Color(red: 0.28, green: 0.12, blue: 0.20),
            ])

        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        // YATSI — Night: deep, quiet night sky
        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

        case (.isha, .clear):
            // Near-black cosmos → midnight blue — subtle depth
            return .init(stops: [
                Color(red: 0.02, green: 0.02, blue: 0.08),
                Color(red: 0.04, green: 0.05, blue: 0.16),
                Color(red: 0.07, green: 0.07, blue: 0.22),
            ])

        case (.isha, .partlyCloudy):
            // Thin cloud dims the stars slightly
            return .init(stops: [
                Color(red: 0.04, green: 0.04, blue: 0.12),
                Color(red: 0.07, green: 0.08, blue: 0.18),
                Color(red: 0.10, green: 0.11, blue: 0.24),
            ])

        case (.isha, .overcast):
            // Overcast night — flat dark charcoal, no star glow
            return .init(stops: [
                Color(red: 0.06, green: 0.06, blue: 0.10),
                Color(red: 0.09, green: 0.09, blue: 0.14),
                Color(red: 0.12, green: 0.12, blue: 0.18),
            ])

        case (.isha, .precipitation):
            // Rainy night — cool blue-charcoal
            return .init(stops: [
                Color(red: 0.05, green: 0.06, blue: 0.14),
                Color(red: 0.08, green: 0.10, blue: 0.20),
                Color(red: 0.10, green: 0.12, blue: 0.24),
            ])

        case (.isha, .snow):
            // Snowy night — diffused cold ambient light, blue-silver
            return .init(stops: [
                Color(red: 0.06, green: 0.08, blue: 0.18),
                Color(red: 0.10, green: 0.12, blue: 0.24),
                Color(red: 0.16, green: 0.18, blue: 0.30),
            ])

        case (.isha, .storm):
            // Stormy night — blackest palette in the catalogue
            return .init(stops: [
                Color(red: 0.02, green: 0.02, blue: 0.06),
                Color(red: 0.04, green: 0.04, blue: 0.12),
                Color(red: 0.07, green: 0.06, blue: 0.16),
            ])
        }
    }
}

// MARK: - Islamic Pattern Overlay

/// A subtly rendered repeating 8-pointed star grid drawn with SwiftUI Canvas.
/// Sits between the gradient and all content at 7% opacity with `.overlay` blend mode.
///
/// The star geometry is a classic Islamic motif (Rub el Hizb variant): 8 outer points
/// alternating with 8 inner points, creating an interlocked star shape.
///
/// To use a custom SVG/PNG pattern instead, replace the Canvas body with:
///   Image("pattern_tile").resizable().aspectRatio(contentMode: .fill)
/// and keep the same `.opacity` and `.blendMode` modifiers.
struct IslamicPatternOverlay: View {

    var body: some View {
        Canvas { context, size in
            let outerR: CGFloat = 13        // Outer star tip radius
            let spacingX: CGFloat = 50      // Horizontal cell size
            let spacingY: CGFloat = 50      // Vertical cell size

            let cols = Int(ceil(size.width  / spacingX)) + 2
            let rows = Int(ceil(size.height / spacingY)) + 2

            for row in -1 ..< rows {
                for col in -1 ..< cols {
                    // Offset every other row to produce an interlocked brick-like grid
                    let xOffset: CGFloat = row % 2 == 0 ? 0 : spacingX / 2
                    let cx = CGFloat(col) * spacingX + xOffset
                    let cy = CGFloat(row) * spacingY

                    let star = eightPointedStar(
                        center: CGPoint(x: cx, y: cy),
                        outerRadius: outerR,
                        innerRadius: outerR * 0.38
                    )
                    context.stroke(
                        star,
                        with: .color(.white),
                        style: StrokeStyle(lineWidth: 0.5, lineCap: .round, lineJoin: .round)
                    )
                }
            }
        }
        .opacity(0.07)
        .blendMode(.overlay)
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }

    /// Builds a Path for an 8-pointed star centered at `center`.
    /// Points alternate between outer tips (at `outerRadius`) and inner indentations (at `innerRadius`).
    private func eightPointedStar(
        center: CGPoint,
        outerRadius: CGFloat,
        innerRadius: CGFloat
    ) -> Path {
        var path = Path()
        let pointCount = 8
        let angleStep  = 2.0 * Double.pi / Double(pointCount)

        for i in 0 ..< pointCount {
            let outerAngle = Double(i) * angleStep - Double.pi / 2
            let innerAngle = outerAngle + angleStep / 2

            let outer = CGPoint(
                x: center.x + CGFloat(cos(outerAngle)) * outerRadius,
                y: center.y + CGFloat(sin(outerAngle)) * outerRadius
            )
            let inner = CGPoint(
                x: center.x + CGFloat(cos(innerAngle)) * innerRadius,
                y: center.y + CGFloat(sin(innerAngle)) * innerRadius
            )

            if i == 0 { path.move(to: outer) } else { path.addLine(to: outer) }
            path.addLine(to: inner)
        }
        path.closeSubpath()
        return path
    }
}

// MARK: - Dynamic Prayer Background

/// The animated, time-and-weather-aware gradient background for Makam.
///
/// Technique — two-layer crossfade:
///   • `base` layer   — the palette currently fully visible on screen.
///   • `overlay` layer — the incoming palette that fades from 0 → 1 over 2.5 seconds.
/// When a transition completes, the overlay is promoted to the base, ensuring
/// every subsequent transition always starts from a clean, fully-resolved state.
///
/// The Islamic geometric pattern overlay renders above both gradient layers
/// but below all app content.
struct DynamicPrayerBackground: View {

    // MARK: - Inputs

    /// The `id` field of the currently active `Prayer` (0–5). Nil before data loads.
    let prayerID:     Int?
    /// Live weather state from `PrayerViewModel`. Falls back to `.clear` mood if not loaded.
    let weatherState: WeatherState

    // MARK: - Crossfade state

    @State private var base:           BackgroundPalette
    @State private var overlay:        BackgroundPalette
    @State private var overlayOpacity: Double = 0.0

    // MARK: - Computed helpers

    private var targetPeriod: PrayerPeriod {
        PrayerPeriod(prayerID: prayerID ?? 5)
    }

    private var targetMood: WeatherMood {
        WeatherMood.from(weatherState)
    }

    // MARK: - Init

    init(prayerID: Int?, weatherState: WeatherState) {
        self.prayerID     = prayerID
        self.weatherState = weatherState

        // Resolve the correct initial palette so the very first frame is accurate,
        // with no transition animation required.
        let period  = PrayerPeriod(prayerID: prayerID ?? 5)
        let mood    = WeatherMood.from(weatherState)
        let palette = PaletteLibrary.palette(for: period, mood: mood)

        _base    = State(initialValue: palette)
        _overlay = State(initialValue: palette)
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // Layer 1 — Stable base: the palette we are transitioning FROM.
            makeGradient(from: base)
                .ignoresSafeArea()

            // Layer 2 — Incoming overlay: fades in when prayer/weather changes.
            makeGradient(from: overlay)
                .ignoresSafeArea()
                .opacity(overlayOpacity)

            // Layer 3 — Islamic geometric pattern (non-interactive, behind all content).
            IslamicPatternOverlay()
        }
        // Observe derived values so a change in either prayer OR weather triggers a transition.
        .onChange(of: targetPeriod) { crossfade() }
        .onChange(of: targetMood)   { crossfade() }
    }

    // MARK: - Gradient helper

    private func makeGradient(from palette: BackgroundPalette) -> LinearGradient {
        LinearGradient(
            colors:     palette.stops,
            startPoint: .top,
            endPoint:   .bottom
        )
    }

    // MARK: - Crossfade transition

    /// Smoothly blends from the current palette to the new target palette.
    ///
    /// State machine:
    ///   1. Promote the previous overlay to the new base (invisible swap — no flash).
    ///   2. Load the new target palette into the overlay at opacity 0.
    ///   3. Animate overlay opacity 0 → 1 over 2.5 seconds (easeInOut).
    ///
    /// If called again before the animation finishes, the in-progress overlay
    /// becomes the new base immediately, preventing visual artifacts.
    private func crossfade() {
        let newPalette = PaletteLibrary.palette(for: targetPeriod, mood: targetMood)

        // Atomically promote + reset (SwiftUI batches these into one render pass)
        base           = overlay
        overlayOpacity = 0.0
        overlay        = newPalette

        withAnimation(.easeInOut(duration: 2.5)) {
            overlayOpacity = 1.0
        }
    }
}

// MARK: - Preview

#Preview("Cycle Prayers & Weather") {
    _PreviewCycler()
        .ignoresSafeArea()
}

/// Interactive preview that cycles through all 6 prayer periods and lets you
/// toggle between clear and rainy weather to verify the crossfade animations.
private struct _PreviewCycler: View {

    @State private var periodIndex = 0
    @State private var useRain     = false

    private let periods: [PrayerPeriod] = PrayerPeriod.allCases

    private var mockWeatherState: WeatherState {
        .loaded(WeatherSnapshot(
            sfSymbol:       useRain ? "cloud.rain.fill" : "sun.max.fill",
            temperature:    18,
            feelsLike:      16,
            humidity:       useRain ? 90 : 42,
            windSpeed:      useRain ? 28 : 8,
            shortCondition: useRain ? "Yağmurlu" : "Açık",
            sunrise:        Date(),
            sunset:         Date()
        ))
    }

    var body: some View {
        ZStack {
            DynamicPrayerBackground(
                prayerID:     periods[periodIndex].rawValue,
                weatherState: mockWeatherState
            )

            VStack(spacing: 20) {
                Spacer()

                VStack(spacing: 6) {
                    Text(periods[periodIndex].previewLabel)
                        .font(.system(size: 24, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)

                    Text(useRain ? "Yağmurlu" : "Açık Hava")
                        .font(.system(size: 14, design: .rounded))
                        .foregroundStyle(.white.opacity(0.55))
                }

                HStack(spacing: 12) {
                    Button("← Önceki") {
                        periodIndex = max(periodIndex - 1, 0)
                    }
                    .disabled(periodIndex == 0)

                    Button(useRain ? "☀︎ Açık" : "☂ Yağmur") {
                        useRain.toggle()
                    }

                    Button("Sonraki →") {
                        periodIndex = min(periodIndex + 1, periods.count - 1)
                    }
                    .disabled(periodIndex == periods.count - 1)
                }
                .buttonStyle(.bordered)
                .foregroundStyle(.white)
                .tint(.white.opacity(0.4))

                Spacer().frame(height: 48)
            }
        }
    }
}

private extension PrayerPeriod {
    var previewLabel: String {
        switch self {
        case .fajr:    return "Fajr — Sabah öncesi"
        case .shuruq:  return "Shuruq — Şafak"
        case .dhuhr:   return "Dhuhr — Gün ortası"
        case .asr:     return "Asr — Öğleden sonra"
        case .maghrib: return "Maghrib — Gün batımı"
        case .isha:    return "Isha — Gece"
        }
    }
}
