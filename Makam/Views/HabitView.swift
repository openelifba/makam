import SwiftUI
import SwiftData

// MARK: - HabitView

struct HabitView: View {
    @State private var selectedDate: Date = Calendar.current.startOfDay(for: .now)
    @State private var showAddTask = false

    var body: some View {
        ZStack {
            Makam.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                WeekCalendarStrip(selectedDate: $selectedDate)
                TaskTimelineContainer(date: selectedDate)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            FABButton { showAddTask = true }
                .padding(.trailing, 24)
                .padding(.bottom, 16)
        }
        .sheet(isPresented: $showAddTask) {
            AddTaskSheet(defaultDate: selectedDate)
                .presentationDetents([.fraction(0.80), .large])
                .presentationBackground(Makam.bg)
                .presentationDragIndicator(.visible)
        }
    }
}

// MARK: - Floating Action Button

private struct FABButton: View {
    let action: () -> Void
    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Makam.bg)
                .frame(width: 52, height: 52)
                .background(Circle().fill(Makam.gold))
                .shadow(color: Makam.gold.opacity(0.40), radius: 12, x: 0, y: 4)
                .scaleEffect(isPressed ? 0.93 : 1.0)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(.easeInOut(duration: 0.08)) { isPressed = true }
                }
                .onEnded { _ in
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { isPressed = false }
                }
        )
    }
}

// MARK: - Week Calendar Strip

private struct WeekCalendarStrip: View {
    @Binding var selectedDate: Date

    private let calendar = Calendar.current
    private var today: Date { calendar.startOfDay(for: .now) }

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
                                withAnimation(.easeInOut(duration: 0.18)) { selectedDate = day }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }
                .onAppear { proxy.scrollTo(today, anchor: .center) }
                .onChange(of: selectedDate) { _, date in
                    withAnimation(.easeInOut(duration: 0.3)) {
                        proxy.scrollTo(calendar.startOfDay(for: date), anchor: .center)
                    }
                }
            }

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

    private var weekdayLabel: String {
        String(date.formatted(.dateTime.weekday(.abbreviated).locale(Self.trLocale)).prefix(3)).uppercased()
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

            Circle()
                .fill(isToday ? Makam.gold : Color.clear)
                .frame(width: 4, height: 4)
        }
        .frame(width: 42)
    }
}

// MARK: - Task Timeline Container

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
            .padding(.bottom, 100) // room above FAB
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

    private var sectionHeader: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.22)) { isExpanded.toggle() }
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

    @State private var showActionMenu = false
    @State private var showEditSheet = false
    @State private var showRescheduleSheet = false
    @State private var showDeleteConfirm = false

    private static let isoFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

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
        .contentShape(Rectangle())
        .onTapGesture { showActionMenu = true }
        .confirmationDialog(task.title, isPresented: $showActionMenu, titleVisibility: .visible) {
            Button("Kopyala") { makeCopy() }
            Button("Yeniden Planla") { showRescheduleSheet = true }
            Button("Yarına Planla") { rescheduleForTomorrow() }
            Button("Düzenle") { showEditSheet = true }
            Button("Sil", role: .destructive) { showDeleteConfirm = true }
            Button("İptal", role: .cancel) {}
        }
        .alert("Görevi Sil", isPresented: $showDeleteConfirm) {
            Button("Sil", role: .destructive) { deleteTask() }
            Button("İptal", role: .cancel) {}
        } message: {
            Text("\"\(task.title)\" silinecek. Emin misiniz?")
        }
        .sheet(isPresented: $showEditSheet) {
            EditTaskSheet(task: task)
                .presentationDetents([.fraction(0.80), .large])
                .presentationBackground(Makam.bg)
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showRescheduleSheet) {
            RescheduleSheet(task: task)
                .presentationDetents([.medium])
                .presentationBackground(Makam.bg)
                .presentationDragIndicator(.visible)
        }
    }

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
                    Circle().fill(Makam.goldDim).frame(width: 22, height: 22)
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Makam.gold)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func makeCopy() {
        let repo = TaskRepository(context: context)
        try? repo.create(
            title: task.title,
            date: task.date,
            timePeriod: task.timePeriod,
            duration: task.duration,
            notes: task.notes
        )
    }

    private func rescheduleForTomorrow() {
        guard let taskDate = Self.isoFormatter.date(from: task.date),
              let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: taskDate)
        else { return }
        task.date = Self.isoFormatter.string(from: tomorrow)
        try? context.save()
    }

    private func deleteTask() {
        let repo = TaskRepository(context: context)
        try? repo.delete(task)
    }
}

// MARK: - Add Task Sheet

private struct AddTaskSheet: View {
    let defaultDate: Date

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var title = ""
    @State private var selectedDate: Date
    @State private var selectedPeriod: TimePeriod = .ogle
    @State private var selectedDuration = 30
    @State private var notes = ""
    @State private var selectedRepeat: RepeatRule = .none
    @State private var customInterval = 2

    private static let isoFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    init(defaultDate: Date) {
        self.defaultDate = defaultDate
        _selectedDate = State(initialValue: defaultDate)
    }

    private var isTitleValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            sheetHeader

            Rectangle()
                .fill(Makam.gold.opacity(0.12))
                .frame(height: 0.5)

            ScrollView {
                VStack(spacing: 22) {
                    titleField
                    dateField
                    timePeriodField
                    durationField
                    repeatField
                    notesField
                    saveButton
                }
                .padding(.horizontal, 20)
                .padding(.top, 22)
                .padding(.bottom, 44)
            }
        }
        .background(Makam.bg.ignoresSafeArea())
    }

    // MARK: Sheet Header

    private var sheetHeader: some View {
        HStack {
            Button("İptal") { dismiss() }
                .font(.system(size: 15, design: .rounded))
                .foregroundStyle(Makam.sandDim)

            Spacer()

            Text("Yeni Görev")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(Makam.sand)

            Spacer()

            Button("Kaydet") { save() }
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(isTitleValid ? Makam.gold : Makam.sandDim.opacity(0.4))
                .disabled(!isTitleValid)
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 16)
    }

    // MARK: Fields

    private var titleField: some View {
        SheetFormField(label: "Görev Başlığı") {
            TextField("Örn: Kuran oku, Zikir çek…", text: $title)
                .font(.system(size: 15, design: .rounded))
                .foregroundStyle(Makam.sand)
                .tint(Makam.gold)
                .padding(.horizontal, 14)
                .padding(.vertical, 13)
                .background(inputBackground)
        }
    }

    private var dateField: some View {
        SheetFormField(label: "Tarih") {
            HStack {
                DatePicker("", selection: $selectedDate, displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .tint(Makam.gold)
                    .environment(\.locale, Locale(identifier: "tr_TR"))
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(inputBackground)
        }
    }

    private var timePeriodField: some View {
        SheetFormField(label: "Vakit") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(TimePeriod.allCases, id: \.self) { period in
                        SelectionPill(
                            label: period.rawValue,
                            isSelected: selectedPeriod == period
                        ) {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                selectedPeriod = period
                            }
                        }
                    }
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 2)
            }
        }
    }

    private var durationField: some View {
        SheetFormField(label: "Süre") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach([5, 10, 15, 20, 30, 45, 60, 90, 120], id: \.self) { mins in
                        SelectionPill(
                            label: durationLabel(mins),
                            isSelected: selectedDuration == mins
                        ) {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                selectedDuration = mins
                            }
                        }
                    }
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 2)
            }
        }
    }

    private var repeatField: some View {
        SheetFormField(label: "Tekrar") {
            VStack(spacing: 0) {
                Menu {
                    ForEach(RepeatRule.allCases, id: \.self) { rule in
                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) { selectedRepeat = rule }
                        } label: {
                            if selectedRepeat == rule {
                                Label(rule.rawValue, systemImage: "checkmark")
                            } else {
                                Text(rule.rawValue)
                            }
                        }
                    }
                } label: {
                    HStack {
                        Text(selectedRepeat.rawValue)
                            .font(.system(size: 15, design: .rounded))
                            .foregroundStyle(Makam.sand)
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Makam.sandDim)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 13)
                    .background(inputBackground)
                }
                .buttonStyle(.plain)

                if selectedRepeat == .custom {
                    HStack {
                        Text("Her")
                            .font(.system(size: 14, design: .rounded))
                            .foregroundStyle(Makam.sandDim)
                        Spacer()
                        HStack(spacing: 16) {
                            Button {
                                if customInterval > 2 { customInterval -= 1 }
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .font(.system(size: 22))
                                    .foregroundStyle(customInterval > 2 ? Makam.gold : Makam.sandDim.opacity(0.4))
                            }
                            .buttonStyle(.plain)
                            Text("\(customInterval) günde bir")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundStyle(Makam.sand)
                                .frame(minWidth: 80, alignment: .center)
                            Button {
                                if customInterval < 30 { customInterval += 1 }
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 22))
                                    .foregroundStyle(customInterval < 30 ? Makam.gold : Makam.sandDim.opacity(0.4))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(inputBackground)
                    .padding(.top, 6)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }

    private var notesField: some View {
        SheetFormField(label: "Notlar (isteğe bağlı)") {
            ZStack(alignment: .topLeading) {
                if notes.isEmpty {
                    Text("Ek notlar veya hatırlatıcı…")
                        .font(.system(size: 14, design: .rounded))
                        .foregroundStyle(Makam.sandDim.opacity(0.45))
                        .padding(.horizontal, 18)
                        .padding(.top, 14)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $notes)
                    .font(.system(size: 14, design: .rounded))
                    .foregroundStyle(Makam.sand)
                    .tint(Makam.gold)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 88)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
            }
            .background(inputBackground)
        }
    }

    private var saveButton: some View {
        Button(action: save) {
            Text("Kaydet")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(isTitleValid ? Makam.bg : Makam.sandDim)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(isTitleValid ? Makam.gold : Makam.gold.opacity(0.18))
                )
        }
        .disabled(!isTitleValid)
        .padding(.top, 6)
    }

    // MARK: Helpers

    private var inputBackground: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(Color.white.opacity(0.05))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Makam.gold.opacity(0.13), lineWidth: 0.5)
            )
    }

    private func durationLabel(_ minutes: Int) -> String {
        switch minutes {
        case ..<60:  return "\(minutes) dk"
        case 60:     return "1s"
        case 90:     return "1s 30dk"
        case 120:    return "2s"
        default:     return "\(minutes / 60)s"
        }
    }

    private func save() {
        guard isTitleValid else { return }
        let trimmedNotes = notes.trimmingCharacters(in: .whitespaces)
        let cleanNotes = trimmedNotes.isEmpty ? nil : trimmedNotes
        let cleanTitle = title.trimmingCharacters(in: .whitespaces)
        let repo = TaskRepository(context: context)
        if selectedRepeat == .none {
            let dateString = Self.isoFormatter.string(from: selectedDate)
            try? repo.create(
                title: cleanTitle,
                date: dateString,
                timePeriod: selectedPeriod,
                duration: selectedDuration,
                notes: cleanNotes
            )
        } else {
            try? repo.createRepeating(
                title: cleanTitle,
                startDate: selectedDate,
                timePeriod: selectedPeriod,
                duration: selectedDuration,
                notes: cleanNotes,
                repeatRule: selectedRepeat,
                repeatInterval: customInterval
            )
        }
        dismiss()
    }
}

// MARK: - Edit Task Sheet

private struct EditTaskSheet: View {
    let task: HabitTask

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var title: String
    @State private var selectedDate: Date
    @State private var selectedPeriod: TimePeriod
    @State private var selectedDuration: Int
    @State private var notes: String
    @State private var selectedRepeat: RepeatRule
    @State private var customInterval: Int

    private static let isoFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    init(task: HabitTask) {
        self.task = task
        _title = State(initialValue: task.title)
        _selectedDate = State(initialValue: Self.isoFormatter.date(from: task.date) ?? .now)
        _selectedPeriod = State(initialValue: task.timePeriod)
        _selectedDuration = State(initialValue: task.duration)
        _notes = State(initialValue: task.notes ?? "")
        _selectedRepeat = State(initialValue: task.repeatRule)
        _customInterval = State(initialValue: max(2, task.repeatInterval))
    }

    private var isTitleValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            sheetHeader
            Rectangle()
                .fill(Makam.gold.opacity(0.12))
                .frame(height: 0.5)
            ScrollView {
                VStack(spacing: 22) {
                    titleField
                    dateField
                    timePeriodField
                    durationField
                    repeatField
                    notesField
                    saveButton
                }
                .padding(.horizontal, 20)
                .padding(.top, 22)
                .padding(.bottom, 44)
            }
        }
        .background(Makam.bg.ignoresSafeArea())
    }

    private var sheetHeader: some View {
        HStack {
            Button("İptal") { dismiss() }
                .font(.system(size: 15, design: .rounded))
                .foregroundStyle(Makam.sandDim)
            Spacer()
            Text("Görevi Düzenle")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(Makam.sand)
            Spacer()
            Button("Kaydet") { save() }
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(isTitleValid ? Makam.gold : Makam.sandDim.opacity(0.4))
                .disabled(!isTitleValid)
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 16)
    }

    private var titleField: some View {
        SheetFormField(label: "Görev Başlığı") {
            TextField("Örn: Kuran oku, Zikir çek…", text: $title)
                .font(.system(size: 15, design: .rounded))
                .foregroundStyle(Makam.sand)
                .tint(Makam.gold)
                .padding(.horizontal, 14)
                .padding(.vertical, 13)
                .background(inputBackground)
        }
    }

    private var dateField: some View {
        SheetFormField(label: "Tarih") {
            HStack {
                DatePicker("", selection: $selectedDate, displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .tint(Makam.gold)
                    .environment(\.locale, Locale(identifier: "tr_TR"))
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(inputBackground)
        }
    }

    private var timePeriodField: some View {
        SheetFormField(label: "Vakit") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(TimePeriod.allCases, id: \.self) { period in
                        SelectionPill(
                            label: period.rawValue,
                            isSelected: selectedPeriod == period
                        ) {
                            withAnimation(.easeInOut(duration: 0.15)) { selectedPeriod = period }
                        }
                    }
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 2)
            }
        }
    }

    private var durationField: some View {
        SheetFormField(label: "Süre") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach([5, 10, 15, 20, 30, 45, 60, 90, 120], id: \.self) { mins in
                        SelectionPill(
                            label: durationLabel(mins),
                            isSelected: selectedDuration == mins
                        ) {
                            withAnimation(.easeInOut(duration: 0.15)) { selectedDuration = mins }
                        }
                    }
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 2)
            }
        }
    }

    private var repeatField: some View {
        SheetFormField(label: "Tekrar") {
            VStack(spacing: 0) {
                Menu {
                    ForEach(RepeatRule.allCases, id: \.self) { rule in
                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) { selectedRepeat = rule }
                        } label: {
                            if selectedRepeat == rule {
                                Label(rule.rawValue, systemImage: "checkmark")
                            } else {
                                Text(rule.rawValue)
                            }
                        }
                    }
                } label: {
                    HStack {
                        Text(selectedRepeat.rawValue)
                            .font(.system(size: 15, design: .rounded))
                            .foregroundStyle(Makam.sand)
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Makam.sandDim)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 13)
                    .background(inputBackground)
                }
                .buttonStyle(.plain)

                if selectedRepeat == .custom {
                    HStack {
                        Text("Her")
                            .font(.system(size: 14, design: .rounded))
                            .foregroundStyle(Makam.sandDim)
                        Spacer()
                        HStack(spacing: 16) {
                            Button {
                                if customInterval > 2 { customInterval -= 1 }
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .font(.system(size: 22))
                                    .foregroundStyle(customInterval > 2 ? Makam.gold : Makam.sandDim.opacity(0.4))
                            }
                            .buttonStyle(.plain)
                            Text("\(customInterval) günde bir")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundStyle(Makam.sand)
                                .frame(minWidth: 80, alignment: .center)
                            Button {
                                if customInterval < 30 { customInterval += 1 }
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 22))
                                    .foregroundStyle(customInterval < 30 ? Makam.gold : Makam.sandDim.opacity(0.4))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(inputBackground)
                    .padding(.top, 6)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }

    private var notesField: some View {
        SheetFormField(label: "Notlar (isteğe bağlı)") {
            ZStack(alignment: .topLeading) {
                if notes.isEmpty {
                    Text("Ek notlar veya hatırlatıcı…")
                        .font(.system(size: 14, design: .rounded))
                        .foregroundStyle(Makam.sandDim.opacity(0.45))
                        .padding(.horizontal, 18)
                        .padding(.top, 14)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $notes)
                    .font(.system(size: 14, design: .rounded))
                    .foregroundStyle(Makam.sand)
                    .tint(Makam.gold)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 88)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
            }
            .background(inputBackground)
        }
    }

    private var saveButton: some View {
        Button(action: save) {
            Text("Kaydet")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(isTitleValid ? Makam.bg : Makam.sandDim)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(isTitleValid ? Makam.gold : Makam.gold.opacity(0.18))
                )
        }
        .disabled(!isTitleValid)
        .padding(.top, 6)
    }

    private var inputBackground: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(Color.white.opacity(0.05))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Makam.gold.opacity(0.13), lineWidth: 0.5)
            )
    }

    private func durationLabel(_ minutes: Int) -> String {
        switch minutes {
        case ..<60:  return "\(minutes) dk"
        case 60:     return "1s"
        case 90:     return "1s 30dk"
        case 120:    return "2s"
        default:     return "\(minutes / 60)s"
        }
    }

    private func save() {
        guard isTitleValid else { return }
        let dateString = Self.isoFormatter.string(from: selectedDate)
        let trimmedNotes = notes.trimmingCharacters(in: .whitespaces)
        let repo = TaskRepository(context: context)
        try? repo.update(
            task,
            title: title.trimmingCharacters(in: .whitespaces),
            date: dateString,
            timePeriod: selectedPeriod,
            duration: selectedDuration,
            notes: trimmedNotes.isEmpty ? nil : trimmedNotes,
            isCompleted: task.isCompleted,
            repeatRule: selectedRepeat,
            repeatInterval: customInterval
        )
        dismiss()
    }
}

// MARK: - Reschedule Sheet

private struct RescheduleSheet: View {
    let task: HabitTask

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var selectedDate: Date
    @State private var selectedPeriod: TimePeriod

    private static let isoFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    init(task: HabitTask) {
        self.task = task
        _selectedDate = State(initialValue: Self.isoFormatter.date(from: task.date) ?? .now)
        _selectedPeriod = State(initialValue: task.timePeriod)
    }

    var body: some View {
        VStack(spacing: 0) {
            sheetHeader
            Rectangle()
                .fill(Makam.gold.opacity(0.12))
                .frame(height: 0.5)
            ScrollView {
                VStack(spacing: 22) {
                    dateField
                    timePeriodField
                    saveButton
                }
                .padding(.horizontal, 20)
                .padding(.top, 22)
                .padding(.bottom, 44)
            }
        }
        .background(Makam.bg.ignoresSafeArea())
    }

    private var sheetHeader: some View {
        HStack {
            Button("İptal") { dismiss() }
                .font(.system(size: 15, design: .rounded))
                .foregroundStyle(Makam.sandDim)
            Spacer()
            Text("Yeniden Planla")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(Makam.sand)
            Spacer()
            Button("Planla") { save() }
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(Makam.gold)
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 16)
    }

    private var dateField: some View {
        SheetFormField(label: "Yeni Tarih") {
            HStack {
                DatePicker("", selection: $selectedDate, displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .tint(Makam.gold)
                    .environment(\.locale, Locale(identifier: "tr_TR"))
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(inputBackground)
        }
    }

    private var timePeriodField: some View {
        SheetFormField(label: "Vakit") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(TimePeriod.allCases, id: \.self) { period in
                        SelectionPill(
                            label: period.rawValue,
                            isSelected: selectedPeriod == period
                        ) {
                            withAnimation(.easeInOut(duration: 0.15)) { selectedPeriod = period }
                        }
                    }
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 2)
            }
        }
    }

    private var saveButton: some View {
        Button(action: save) {
            Text("Planla")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(Makam.bg)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(RoundedRectangle(cornerRadius: 14).fill(Makam.gold))
        }
        .padding(.top, 6)
    }

    private var inputBackground: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(Color.white.opacity(0.05))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Makam.gold.opacity(0.13), lineWidth: 0.5)
            )
    }

    private func save() {
        task.date = Self.isoFormatter.string(from: selectedDate)
        task.timePeriod = selectedPeriod
        try? context.save()
        dismiss()
    }
}

// MARK: - Sheet Form Field

private struct SheetFormField<Content: View>: View {
    let label: String
    let content: Content

    init(label: String, @ViewBuilder content: () -> Content) {
        self.label = label
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .tracking(Makam.trackingLoose)
                .foregroundStyle(Makam.sandDim)
            content
        }
    }
}

// MARK: - Selection Pill

private struct SelectionPill: View {
    let label: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(label)
                .font(.system(size: 13,
                              weight: isSelected ? .semibold : .regular,
                              design: .rounded))
                .foregroundStyle(isSelected ? Makam.bg : Makam.sand)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? Makam.gold : Color.white.opacity(0.07))
                        .overlay(
                            Capsule()
                                .strokeBorder(
                                    Makam.gold.opacity(isSelected ? 0 : 0.22),
                                    lineWidth: 0.5
                                )
                        )
                )
        }
        .buttonStyle(.plain)
    }
}
