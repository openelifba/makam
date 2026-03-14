import SwiftUI
import SwiftData

// MARK: - HabitView

struct HabitView: View {
    @State private var selectedDate: Date = Calendar.current.startOfDay(for: .now)

    var body: some View {
        ZStack {
            Makam.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                WeekCalendarStrip(selectedDate: $selectedDate)
                TaskTimelineContainer(date: selectedDate)
            }
        }
    }
}

// MARK: - Week Calendar Strip

private struct WeekCalendarStrip: View {
    @Binding var selectedDate: Date

    private let calendar = Calendar.current
    private var today: Date { calendar.startOfDay(for: .now) }

    /// ±21-day window gives the user three weeks in each direction without
    /// loading an unbounded list.
    private var days: [Date] {
        (-21 ... 21).compactMap {
            calendar.date(byAdding: .day, value: $0, to: today)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(days, id: \.self) { day in
                            DayCell(
                                date: day,
                                isSelected: calendar.isDate(day, inSameDayAs: selectedDate),
                                isToday: calendar.isDateInToday(day)
                            )
                            .id(day)
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.18)) {
                                    selectedDate = day
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }
                .onAppear {
                    proxy.scrollTo(today, anchor: .center)
                }
                .onChange(of: selectedDate) { _, date in
                    withAnimation(.easeInOut(duration: 0.3)) {
                        proxy.scrollTo(calendar.startOfDay(for: date), anchor: .center)
                    }
                }
            }

            // Hairline divider below the strip
            Rectangle()
                .fill(Makam.gold.opacity(0.15))
                .frame(height: 0.5)
                .padding(.horizontal, 16)
        }
    }
}

// MARK: - Day Cell

private struct DayCell: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool

    private static let trLocale = Locale(identifier: "tr_TR")

    /// 3-letter Turkish weekday abbreviation, e.g. "Pzt", "Sal", "Çar".
    private var weekdayLabel: String {
        String(
            date.formatted(.dateTime.weekday(.abbreviated).locale(Self.trLocale))
                .prefix(3)
        ).uppercased()
    }

    private var dayNumber: String {
        date.formatted(.dateTime.day().locale(Self.trLocale))
    }

    var body: some View {
        VStack(spacing: 5) {
            Text(weekdayLabel)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(isSelected ? Makam.gold : Makam.sandDim)

            ZStack {
                if isSelected {
                    Circle().fill(Makam.goldDim)
                    Circle().strokeBorder(Makam.gold.opacity(0.45), lineWidth: 1)
                }
                Text(dayNumber)
                    .font(.system(size: 15,
                                  weight: isSelected ? .semibold : .regular,
                                  design: .rounded))
                    .foregroundStyle(isSelected ? Makam.sand : Makam.sandDim)
            }
            .frame(width: 34, height: 34)

            // Today indicator dot
            Circle()
                .fill(isToday ? Makam.gold : Color.clear)
                .frame(width: 4, height: 4)
        }
        .frame(width: 42)
    }
}

// MARK: - Task Timeline Container
//
// SwiftData's @Query predicate must be set at init time, so we route through a
// thin container that re-creates the body view whenever the date string changes,
// which causes @Query to reinitialise with the new predicate.

private struct TaskTimelineContainer: View {
    let date: Date

    private var dateString: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    var body: some View {
        TaskTimelineBody(dateString: dateString)
    }
}

private struct TaskTimelineBody: View {
    @Query private var tasks: [HabitTask]

    init(dateString: String) {
        _tasks = Query(filter: #Predicate<HabitTask> { $0.date == dateString })
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(TimePeriod.allCases, id: \.self) { period in
                    PeriodSectionView(
                        period: period,
                        tasks: tasks.filter { $0.timePeriod == period }
                    )
                }
            }
            .padding(.top, 6)
            .padding(.bottom, 40)
        }
    }
}

// MARK: - Period Section

private struct PeriodSectionView: View {
    let period: TimePeriod
    let tasks: [HabitTask]

    @State private var isExpanded = true

    private var symbol: String {
        switch period {
        case .imsak:  return "moon.stars"
        case .gunes:  return "sunrise"
        case .ogle:   return "sun.max"
        case .ikindi: return "sun.haze"
        case .aksam:  return "sunset"
        case .yatsi:  return "moon.zzz"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            sectionHeader

            // Full-width hairline under the header
            Rectangle()
                .fill(Makam.gold.opacity(0.10))
                .frame(height: 0.5)
                .padding(.leading, 20)

            if isExpanded {
                sectionBody
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    // MARK: Header

    private var sectionHeader: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.22)) {
                isExpanded.toggle()
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .font(.system(size: 13, weight: .light))
                    .foregroundStyle(Makam.gold)
                    .frame(width: 18)

                Text(period.rawValue.uppercased())
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .tracking(Makam.trackingLoose)
                    .foregroundStyle(Makam.sand)

                Spacer()

                // Task count badge — shows "0" when empty, gold capsule when populated
                if tasks.isEmpty {
                    Text("0")
                        .font(.system(size: 11, weight: .regular, design: .rounded))
                        .foregroundStyle(Makam.sandDim)
                } else {
                    Text("\(tasks.count)")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(Makam.gold)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Makam.goldDim))
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Makam.sandDim)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    .animation(.easeInOut(duration: 0.22), value: isExpanded)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 13)
        }
        .buttonStyle(.plain)
    }

    // MARK: Body

    @ViewBuilder
    private var sectionBody: some View {
        if tasks.isEmpty {
            HStack {
                Text("Bu vakitte görev yok")
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundStyle(Makam.sandDim.opacity(0.55))
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 14)
        } else {
            VStack(spacing: 8) {
                ForEach(tasks) { task in
                    TaskCard(task: task)
                        .padding(.horizontal, 16)
                }
            }
            .padding(.top, 8)
            .padding(.bottom, 14)
        }
    }
}

// MARK: - Task Card

private struct TaskCard: View {
    let task: HabitTask

    @Environment(\.modelContext) private var context

    var body: some View {
        HStack(spacing: 12) {
            completionButton

            VStack(alignment: .leading, spacing: 3) {
                Text(task.title)
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundStyle(task.isCompleted ? Makam.sandDim : Makam.sand)
                    .strikethrough(task.isCompleted, color: Makam.sandDim)
                    .lineLimit(2)

                HStack(spacing: 10) {
                    Label("\(task.duration) dk", systemImage: "clock")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(Makam.sandDim)

                    if let notes = task.notes, !notes.isEmpty {
                        Text(notes)
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(Makam.sandDim.opacity(0.7))
                            .lineLimit(1)
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Makam.goldDim.opacity(task.isCompleted ? 0.45 : 1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Makam.gold.opacity(0.14), lineWidth: 0.5)
                )
        )
    }

    // Tappable circle that toggles isCompleted and persists immediately
    private var completionButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                task.isCompleted.toggle()
                try? context.save()
            }
        } label: {
            ZStack {
                Circle()
                    .strokeBorder(
                        task.isCompleted ? Makam.gold : Makam.sandDim.opacity(0.35),
                        lineWidth: 1.5
                    )
                    .frame(width: 22, height: 22)

                if task.isCompleted {
                    Circle()
                        .fill(Makam.goldDim)
                        .frame(width: 22, height: 22)
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Makam.gold)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
