import SwiftUI

struct ContentView: View {
    @EnvironmentObject var viewModel: PrayerViewModel
    @EnvironmentObject var lang: LanguageManager

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
                VStack(spacing: 8) {
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
                    .applyWeatherSheetPresentation()
            }
        }
    }

    // MARK: - Header

    private var headerView: some View {
        VStack(spacing: 10) {
            HStack(spacing: 6) {
                Text(lang.str(.contentToday))
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
                PrayerNameLabel(name: lang.prayerName(forId: ctx.current.id), size: 26)

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
                    Text(lang.untilText(prayerName: lang.prayerName(forId: ctx.next.id)))
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

                    Text(lang.prayerName(forId: prayer.id))
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
            Button(lang.str(.contentRetry)) {
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

/// Gold-themed solar arc: full 24-hour x-axis, bold daytime arc, thick dim
/// nighttime arc, prayer markers with labels, gold sun glow indicator.
struct SunArcView: View {
    let prayers: [Prayer]
    let currentPrayerID: Int

    private var sunriseTime: Date? { prayers.count > 1 ? prayers[1].time : nil }
    private var sunsetTime:  Date? { prayers.count > 4 ? prayers[4].time : nil }

    private func altitude(at date: Date) -> Double {
        guard let rise = sunriseTime, let set = sunsetTime else { return -0.1 }
        let t = date.timeIntervalSince1970
        let r = rise.timeIntervalSince1970
        let s = set.timeIntervalSince1970
        guard s > r else { return -0.1 }
        return sin(.pi * (t - r) / (s - r))
    }

    var body: some View {
        Canvas { ctx, size in
            let gold = Color(red: 0.780, green: 0.620, blue: 0.340)
            let now  = Date()
            let steps = 400

            guard let rise = sunriseTime, let set = sunsetTime else { return }
            let dayStart = Calendar.current.startOfDay(for: rise)
            guard let dayEnd = Calendar.current.date(byAdding: .day, value: 1, to: dayStart) else { return }
            let daySpan = dayEnd.timeIntervalSince(dayStart)
            guard daySpan > 0 else { return }

            let horizonY:  CGFloat = size.height * 0.55
            let amplitude: CGFloat = size.height * 0.40

            func xFor(_ date: Date) -> CGFloat {
                CGFloat(max(0, min(1, date.timeIntervalSince(dayStart) / daySpan))) * size.width
            }
            func yFor(_ alt: Double) -> CGFloat {
                horizonY - CGFloat(alt) * amplitude
            }
            let stepPt: (Int) -> CGPoint = { i in
                let frac = Double(i) / Double(steps)
                let t    = dayStart.timeIntervalSince1970 + frac * daySpan
                return CGPoint(x: CGFloat(frac) * size.width,
                               y: yFor(altitude(at: Date(timeIntervalSince1970: t))))
            }

            let riseStep = Int(max(0, min(Double(steps), rise.timeIntervalSince(dayStart) / daySpan * Double(steps))))
            let setStep  = Int(max(0, min(Double(steps), set.timeIntervalSince(dayStart)  / daySpan * Double(steps))))
            let riseX = xFor(rise)
            let setX  = xFor(set)
            let noonX = (riseX + setX) / 2
            let noonY = yFor(1.0)

            // ── Horizon line ──────────────────────────────────────────────────
            var hl = Path()
            hl.move(to: CGPoint(x: 0, y: horizonY))
            hl.addLine(to: CGPoint(x: size.width, y: horizonY))
            ctx.stroke(hl, with: .color(gold.opacity(0.15)), lineWidth: 0.5)

            // ── Warm fill under daytime arc ───────────────────────────────────
            if riseStep < setStep {
                var fill = Path()
                fill.move(to: CGPoint(x: riseX, y: horizonY))
                for i in riseStep...setStep { fill.addLine(to: stepPt(i)) }
                fill.addLine(to: CGPoint(x: setX, y: horizonY))
                fill.closeSubpath()
                ctx.fill(fill, with: .linearGradient(
                    Gradient(colors: [gold.opacity(0.18), .clear]),
                    startPoint: CGPoint(x: noonX, y: noonY),
                    endPoint:   CGPoint(x: noonX, y: horizonY)))
            }

            // ── Arc ───────────────────────────────────────────────────────────
            // Nighttime before sunrise — thick, dim
            if riseStep > 0 {
                var p = Path(); p.move(to: stepPt(0))
                for i in 1...riseStep { p.addLine(to: stepPt(i)) }
                ctx.stroke(p, with: .color(gold.opacity(0.28)),
                           style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
            }
            // Daytime — bold, bright gold + soft glow pass
            if riseStep < setStep {
                var p = Path(); p.move(to: stepPt(riseStep))
                for i in (riseStep + 1)...setStep { p.addLine(to: stepPt(i)) }
                // Glow
                ctx.stroke(p, with: .color(gold.opacity(0.18)),
                           style: StrokeStyle(lineWidth: 12, lineCap: .round, lineJoin: .round))
                // Bold arc
                ctx.stroke(p, with: .color(gold.opacity(0.92)),
                           style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
            }
            // Nighttime after sunset — thick, dim
            if setStep < steps {
                var p = Path(); p.move(to: stepPt(setStep))
                for i in (setStep + 1)...steps { p.addLine(to: stepPt(i)) }
                ctx.stroke(p, with: .color(gold.opacity(0.28)),
                           style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
            }

            // ── Prayer time markers (skip active — sun dot marks current position) ──
            for prayer in prayers where prayer.id != currentPrayerID {
                let px       = xFor(prayer.time)
                let pAlt     = altitude(at: prayer.time)
                let py       = yFor(pAlt)
                let isPast   = prayer.time < now

                let dotR: CGFloat = 2.5
                let dotColor: Color = isPast ? gold.opacity(0.55) : Color.white.opacity(0.30)

                ctx.fill(Path(ellipseIn: CGRect(x: px - dotR, y: py - dotR,
                                                width: dotR * 2, height: dotR * 2)),
                         with: .color(dotColor))
            }

            // ── Sun position dot (gold glow) ──────────────────────────────────
            let sunX = xFor(now)
            let sunY = yFor(altitude(at: now))
            ctx.fill(Path(ellipseIn: CGRect(x: sunX - 14, y: sunY - 14, width: 28, height: 28)),
                     with: .color(gold.opacity(0.15)))
            ctx.fill(Path(ellipseIn: CGRect(x: sunX -  8, y: sunY -  8, width: 16, height: 16)),
                     with: .color(gold.opacity(0.30)))
            ctx.fill(Path(ellipseIn: CGRect(x: sunX -  4, y: sunY -  4, width:  8, height:  8)),
                     with: .color(gold))
        }
        .frame(height: 130)
        .padding(.horizontal, 16)
    }
}

// MARK: - iOS 15 Compatibility

private extension View {
    @ViewBuilder
    func applyWeatherSheetPresentation() -> some View {
        if #available(iOS 16.0, *) {
            self
                .presentationDetents([.fraction(0.45)])
                .presentationDragIndicator(.hidden)
        } else {
            self
        }
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
