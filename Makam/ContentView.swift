import SwiftUI

struct ContentView: View {
    @EnvironmentObject var viewModel: PrayerViewModel

    @State private var showWeatherSheet = false

    var body: some View {
        ZStack {
            // Dynamic gradient that shifts based on the active prayer period and live weather.
            DynamicPrayerBackground(
                prayerID:     viewModel.context?.current.id,
                weatherState: viewModel.weatherState
            )

            if viewModel.isLoading && viewModel.schedule == nil {
                ProgressView()
                    .tint(Makam.gold)
            } else if let schedule = viewModel.schedule {
                VStack(spacing: 24) {
                    headerView

                    if let ctx = viewModel.context {
                        activePrayerCard(ctx: ctx)
                    }

                    prayerList(schedule: schedule)

                    Spacer()
                }
                .padding(.top, 20)
            } else if let error = viewModel.errorMessage {
                errorView(error)
            }
        }
        .sheet(isPresented: $showWeatherSheet) {
            if case .loaded(let snapshot) = viewModel.weatherState {
                WeatherDetailSheet(snapshot: snapshot, schedule: viewModel.schedule)
                    .presentationDetents([.fraction(0.45)])
                    .presentationBackground(Makam.bg)
                    .presentationDragIndicator(.hidden)
            }
        }
    }

    // MARK: - Header

    private var headerView: some View {
        VStack(spacing: 10) {
            HStack(spacing: 6) {
                Text("BUGÜN")
                    .foregroundStyle(Makam.sandDim)
                Rectangle()
                    .fill(Makam.sandDim)
                    .frame(width: 1, height: 10)
                Image(systemName: "location.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(Makam.gold)
                Text(viewModel.locationName)
                    .foregroundStyle(Makam.gold)
            }
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Makam.gold.opacity(0.40), lineWidth: 1))

            WeatherChip(state: viewModel.weatherState, showSheet: $showWeatherSheet)
        }
    }

    // MARK: - Active Prayer Card

    private func activePrayerCard(ctx: PrayerContext) -> some View {
        VStack(spacing: 20) {
            if let schedule = viewModel.schedule {
                SunArcView(
                    prayers: schedule.prayers,
                    currentPrayerID: ctx.current.id
                )
            }

            VStack(spacing: 4) {
                PrayerNameLabel(name: ctx.current.name, size: 26)

                Text(timeString(ctx.current.time))
                    .font(.system(size: 16, weight: .light, design: .rounded))
                    .foregroundStyle(Makam.sandDim)
            }

            VStack(spacing: 4) {
                Text(viewModel.context?.countdownHMS() ?? "--:--:--")
                    .font(.system(size: 32, weight: .medium, design: .monospaced))
                    .foregroundStyle(Makam.white)

                HStack(spacing: 4) {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 10))
                    Text("\(ctx.next.name)'ya kadar")
                }
                .font(.system(size: 14, weight: .regular, design: .rounded))
                .foregroundStyle(Makam.sandDim)
            }
        }
        .padding(.vertical, 20)
    }

    // MARK: - Prayer List

    private func prayerList(schedule: DailyPrayerSchedule) -> some View {
        VStack(spacing: 12) {
            ForEach(schedule.prayers) { prayer in
                HStack {
                    Image(systemName: prayer.symbol)
                        .font(.system(size: 16, weight: .light))
                        .frame(width: 24)
                        .foregroundStyle(Makam.gold)

                    Text(prayer.name)
                        .font(.system(size: 16, weight: .regular, design: .rounded))
                        .foregroundStyle(Makam.sand)

                    Spacer()

                    Text(timeString(prayer.time))
                        .font(.system(size: 16, weight: .light, design: .monospaced))
                        .foregroundStyle(Makam.white.opacity(0.8))
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(viewModel.context?.current.id == prayer.id ? Makam.goldDim : Color.clear)
                )
                .padding(.horizontal, 16)
            }
        }
    }

    // MARK: - Error

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(.red)
            Text(message)
                .multilineTextAlignment(.center)
                .foregroundStyle(Makam.sand)
            Button("Tekrar Dene") {
                Task { await viewModel.fetchPrayers() }
            }
            .buttonStyle(.bordered)
            .tint(Makam.gold)
        }
        .padding()
    }

    // MARK: - Helpers

    private func timeString(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"
        return fmt.string(from: date)
    }
}

// MARK: - Design Tokens

enum Makam {
    static let sand       = Color(red: 0.910, green: 0.835, blue: 0.690)
    static let sandDim    = Color(red: 0.910, green: 0.835, blue: 0.690).opacity(0.45)
    static let gold       = Color(red: 0.780, green: 0.620, blue: 0.340)
    static let goldDim    = Color(red: 0.780, green: 0.620, blue: 0.340).opacity(0.18)
    static let white      = Color.white
    static let bg         = Color(red: 0.08, green: 0.08, blue: 0.10)
    static let trackingLoose: CGFloat = 2.5
}

// MARK: - Shared Components

/// Sun-arc visualization showing all prayer times as nodes on the day's arc.
/// Past prayers are shown as solid gold dots, the current prayer as a hollow
/// white ring, and future prayers as dim white dots — mirroring the sun's path.
struct SunArcView: View {
    let prayers: [Prayer]
    let currentPrayerID: Int

    private var firstTime: Date { prayers.first?.time ?? Date() }
    private var lastTime:  Date { prayers.last?.time  ?? Date() }

    private func timeFraction(_ date: Date) -> Double {
        let total = lastTime.timeIntervalSince(firstTime)
        guard total > 0 else { return 0 }
        return max(0, min(1, date.timeIntervalSince(firstTime) / total))
    }

    /// Point on a quadratic bezier: start=(0,h), control=(w/2, topPad), end=(w,h).
    private func arcPoint(t: Double, w: CGFloat, h: CGFloat, topPad: CGFloat = 10) -> CGPoint {
        let t = CGFloat(t)
        return CGPoint(
            x: t * w,
            y: (1-t)*(1-t)*h + 2*t*(1-t)*topPad + t*t*h
        )
    }

    var body: some View {
        let sunFrac  = timeFraction(Date())
        let minH: CGFloat = 55
        let maxH: CGFloat = 130
        let canvasH  = minH + (maxH - minH) * CGFloat(sin(max(0, min(1, sunFrac)) * .pi))

        Canvas { ctx, size in
            let steps = 200
            let gold  = Color(red: 0.780, green: 0.620, blue: 0.340)

            // ── Full arc (dim background) ──────────────────────────────────
            var fullPath = Path()
            fullPath.move(to: arcPoint(t: 0, w: size.width, h: size.height))
            for i in 1...steps {
                fullPath.addLine(to: arcPoint(t: Double(i)/Double(steps), w: size.width, h: size.height))
            }
            ctx.stroke(fullPath, with: .color(.white.opacity(0.12)),
                       style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))

            // ── Elapsed arc (gold, up to current time) ─────────────────────
            let pastSteps = max(1, Int(sunFrac * Double(steps)))
            var pastPath = Path()
            pastPath.move(to: arcPoint(t: 0, w: size.width, h: size.height))
            for i in 1...pastSteps {
                pastPath.addLine(to: arcPoint(t: Double(i)/Double(steps), w: size.width, h: size.height))
            }
            ctx.stroke(pastPath, with: .color(gold.opacity(0.75)),
                       style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))

            // ── Prayer nodes ───────────────────────────────────────────────
            for prayer in prayers {
                let frac   = timeFraction(prayer.time)
                let pt     = arcPoint(t: frac, w: size.width, h: size.height)
                let isPast = prayer.time <= Date()
                let r: CGFloat = 5
                let rect = CGRect(x: pt.x - r, y: pt.y - r, width: r*2, height: r*2)
                if isPast {
                    ctx.fill(Path(ellipseIn: rect), with: .color(gold.opacity(0.90)))
                } else {
                    ctx.fill(Path(ellipseIn: rect), with: .color(.white.opacity(0.55)))
                }
            }

            // ── Sun position indicator (current moment on arc) ─────────────
            if sunFrac > 0 && sunFrac < 1 {
                let sunPt   = arcPoint(t: sunFrac, w: size.width, h: size.height)
                let glowR: CGFloat = 11
                let dotR:  CGFloat = 5
                let glowRect = CGRect(x: sunPt.x - glowR, y: sunPt.y - glowR, width: glowR*2, height: glowR*2)
                let dotRect  = CGRect(x: sunPt.x - dotR,  y: sunPt.y - dotR,  width: dotR*2,  height: dotR*2)
                ctx.fill(Path(ellipseIn: glowRect), with: .color(gold.opacity(0.25)))
                ctx.fill(Path(ellipseIn: dotRect),  with: .color(gold))
            }
        }
        .frame(height: canvasH)
        .padding(.horizontal, 16)
    }
}

struct PrayerNameLabel: View {
    let name: String
    let size: CGFloat

    var body: some View {
        Text(name.uppercased())
            .font(.system(size: size, weight: .semibold, design: .rounded))
            .tracking(Makam.trackingLoose)
            .foregroundStyle(Makam.sand)
    }
}
