import SwiftUI

struct ContentView: View {
    @EnvironmentObject var viewModel: PrayerViewModel
    @State private var showSettings = false

    var body: some View {
        ZStack {
            Makam.bg.ignoresSafeArea()

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
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environmentObject(viewModel)
        }
    }

    private var headerView: some View {
        ZStack {
            // Centered logo + location name
            VStack(spacing: 8) {
                Image("MakamLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 60, height: 60)

                HStack(spacing: 6) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Makam.gold)
                    Text(viewModel.locationName)
                        .font(.system(size: 22, weight: .regular, design: .rounded))
                        .foregroundStyle(Makam.sand)
                }
            }

            // Settings button aligned to trailing edge
            HStack {
                Spacer()
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 20, weight: .light))
                        .foregroundStyle(Makam.sandDim)
                }
                .padding(.trailing, 20)
            }
        }
    }
    
    private func activePrayerCard(ctx: PrayerContext) -> some View {
        VStack(spacing: 16) {
            ZStack {
                PrayerProgressRing(
                    progress: ctx.elapsedFraction(),
                    diameter: 180,
                    lineWidth: 6
                )
                
                VStack(spacing: 8) {
                    PrayerNameLabel(name: ctx.current.name, size: 28)
                    
                    Text(timeString(ctx.current.time))
                        .font(.system(size: 20, weight: .light, design: .rounded))
                        .foregroundStyle(Makam.sandDim)
                }
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
    
    private func timeString(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"
        return fmt.string(from: date)
    }
}

// MARK: - Reused Design Tokens & Components (Simplified for App)

private enum Makam {
    static let sand       = Color(red: 0.910, green: 0.835, blue: 0.690)
    static let sandDim    = Color(red: 0.910, green: 0.835, blue: 0.690).opacity(0.45)
    static let gold       = Color(red: 0.780, green: 0.620, blue: 0.340)
    static let goldDim    = Color(red: 0.780, green: 0.620, blue: 0.340).opacity(0.18)
    static let white      = Color.white
    static let bg         = Color(red: 0.08, green: 0.08, blue: 0.10)
    static let trackingLoose: CGFloat = 2.5
}

struct PrayerProgressRing: View {
    let progress: Double
    let diameter: CGFloat
    let lineWidth: CGFloat
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(Makam.goldDim, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: CGFloat(progress))
                .stroke(Makam.gold, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: diameter, height: diameter)
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
