import SwiftUI
import SwiftData

// MARK: - HabitView

struct HabitView: View {
    @EnvironmentObject var lang: LanguageManager
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
    @EnvironmentObject var lang: LanguageManager
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
                                isToday: calendar.isDateInToday(day),
                                locale: lang.current.locale
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
    let locale: Locale

    private var weekdayLabel: String {
        String(date.formatted(.dateTime.weekday(.abbreviated).locale(locale)).prefix(3)).uppercased()
    }

    private var dayNumber: String {
        date.formatted(.dateTime.day().locale(locale))
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
    @EnvironmentObject var lang: LanguageManager
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
                Text(lang.timePeriodName(period).uppercased())
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
                Text(lang.str(.habitNoTasks))
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
    @EnvironmentObject var lang: LanguageManager
    let task: HabitTask
    @Environment(\.modelContext) private var context

    @State private var showActionMenu = false
    @State private var showEditSheet = false
    @State private var showRescheduleSheet = false
    @State private var showDeleteConfirm = false
    @State private var showSeriesDeleteDialog = false

    private static let isoFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    var body: some View {
        if task.modelContext == nil { return AnyView(EmptyView()) }
        return AnyView(taskContent)
    }

    @ViewBuilder
    private var taskContent: some View {
        HStack(spacing: 12) {
            completionButton
            VStack(alignment: .leading, spacing: 3) {
                Text(task.title)
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundStyle(task.isCompleted ? Makam.sandDim : Makam.sand)
                    .strikethrough(task.isCompleted, color: Makam.sandDim)
                    .lineLimit(2)
                HStack(spacing: 10) {
                    Label(lang.durationLabel(task.duration), systemImage: "clock")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(Makam.sandDim)
                    if task.repeatFrequency != .none {
                        Label(lang.repeatLabel(task.repeatFrequency), systemImage: "arrow.clockwise")
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(Makam.gold.opacity(0.75))
                    }
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
            Button(lang.str(.habitCopy)) { makeCopy() }
            Button(lang.str(.habitReschedule)) { showRescheduleSheet = true }
            Button(lang.str(.habitTomorrow)) { rescheduleForTomorrow() }
            Button(lang.str(.habitEdit)) { showEditSheet = true }
            Button(lang.str(.habitDelete), role: .destructive) {
                if task.seriesID != nil {
                    showSeriesDeleteDialog = true
                } else {
                    showDeleteConfirm = true
                }
            }
            Button(lang.str(.habitCancel), role: .cancel) {}
        }
        .alert(lang.str(.habitDeleteTaskTitle), isPresented: $showDeleteConfirm) {
            Button(lang.str(.habitDelete), role: .destructive) { deleteTask() }
            Button(lang.str(.habitCancel), role: .cancel) {}
        } message: {
            Text(lang.str(.habitDeleteConfirm).replacingOccurrences(of: "%@", with: task.title))
        }
        .confirmationDialog(lang.str(.habitDeleteRecurringTitle), isPresented: $showSeriesDeleteDialog, titleVisibility: .visible) {
            Button(lang.str(.habitDeleteOnlyThis), role: .destructive) { deleteTask() }
            Button(lang.str(.habitDeleteAllSeries), role: .destructive) { deleteAllInSeries() }
            Button(lang.str(.habitCancel), role: .cancel) {}
        } message: {
            Text(lang.str(.habitDeleteRecurringMessage))
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

    private func deleteAllInSeries() {
        guard let sid = task.seriesID else { return }
        let repo = TaskRepository(context: context)
        try? repo.deleteAllInSeries(seriesID: sid)
    }
}

// MARK: - Add Task Sheet

private struct AddTaskSheet: View {
    @EnvironmentObject var lang: LanguageManager
    let defaultDate: Date

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var title = ""
    @State private var selectedDate: Date
    @State private var selectedPeriod: TimePeriod = .ogle
    @State private var selectedDuration = 30
    @State private var selectedRepeat: RepeatFrequency = .none
    @State private var notes = ""

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
            Button(lang.str(.habitCancel)) { dismiss() }
                .font(.system(size: 15, design: .rounded))
                .foregroundStyle(Makam.sandDim)

            Spacer()

            Text(lang.str(.habitNewTask))
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(Makam.sand)

            Spacer()

            Button(lang.str(.habitSave)) { save() }
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
        SheetFormField(label: lang.str(.habitTitleField)) {
            TextField(lang.str(.habitTitlePlaceholder), text: $title)
                .font(.system(size: 15, design: .rounded))
                .foregroundStyle(Makam.sand)
                .tint(Makam.gold)
                .padding(.horizontal, 14)
                .padding(.vertical, 13)
                .background(inputBackground)
        }
    }

    private var dateField: some View {
        SheetFormField(label: lang.str(.habitDateField)) {
            HStack {
                DatePicker("", selection: $selectedDate, displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .tint(Makam.gold)
                    .environment(\.locale, lang.current.locale)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(inputBackground)
        }
    }

    private var timePeriodField: some View {
        SheetFormField(label: lang.str(.habitPeriodField)) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(TimePeriod.allCases, id: \.self) { period in
                        SelectionPill(
                            label: lang.timePeriodName(period),
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
        SheetFormField(label: lang.str(.habitDurationField)) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach([5, 10, 15, 20, 30, 45, 60, 90, 120], id: \.self) { mins in
                        SelectionPill(
                            label: lang.durationLabel(mins),
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
        SheetFormField(label: lang.str(.habitRepeatField)) {
            Menu {
                ForEach(RepeatFrequency.allCases, id: \.self) { freq in
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) { selectedRepeat = freq }
                    } label: {
                        if selectedRepeat == freq {
                            Label(lang.repeatLabel(freq), systemImage: "checkmark")
                        } else {
                            Text(lang.repeatLabel(freq))
                        }
                    }
                }
            } label: {
                HStack {
                    Text(lang.repeatLabel(selectedRepeat))
                        .font(.system(size: 14, design: .rounded))
                        .foregroundStyle(selectedRepeat == .none ? Makam.sandDim : Makam.gold)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Makam.sandDim)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 13)
                .background(inputBackground)
            }
        }
    }

    private var notesField: some View {
        SheetFormField(label: lang.str(.habitNotesField)) {
            ZStack(alignment: .topLeading) {
                if notes.isEmpty {
                    Text(lang.str(.habitNotesPlaceholder))
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
            Text(lang.str(.habitSave))
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

    private func save() {
        guard isTitleValid else { return }
        let dateString = Self.isoFormatter.string(from: selectedDate)
        let trimmedNotes = notes.trimmingCharacters(in: .whitespaces)
        let repo = TaskRepository(context: context)
        try? repo.createWithRepeat(
            title: title.trimmingCharacters(in: .whitespaces),
            date: dateString,
            timePeriod: selectedPeriod,
            duration: selectedDuration,
            notes: trimmedNotes.isEmpty ? nil : trimmedNotes,
            repeatFrequency: selectedRepeat
        )
        dismiss()
    }
}

// MARK: - Edit Task Sheet

private struct EditTaskSheet: View {
    @EnvironmentObject var lang: LanguageManager
    let task: HabitTask

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var title: String
    @State private var selectedDate: Date
    @State private var selectedPeriod: TimePeriod
    @State private var selectedDuration: Int
    @State private var selectedRepeat: RepeatFrequency
    @State private var notes: String

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
        _selectedRepeat = State(initialValue: task.repeatFrequency)
        _notes = State(initialValue: task.notes ?? "")
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
            Button(lang.str(.habitCancel)) { dismiss() }
                .font(.system(size: 15, design: .rounded))
                .foregroundStyle(Makam.sandDim)
            Spacer()
            Text(lang.str(.habitEditTask))
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(Makam.sand)
            Spacer()
            Button(lang.str(.habitSave)) { save() }
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(isTitleValid ? Makam.gold : Makam.sandDim.opacity(0.4))
                .disabled(!isTitleValid)
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 16)
    }

    private var titleField: some View {
        SheetFormField(label: lang.str(.habitTitleField)) {
            TextField(lang.str(.habitTitlePlaceholder), text: $title)
                .font(.system(size: 15, design: .rounded))
                .foregroundStyle(Makam.sand)
                .tint(Makam.gold)
                .padding(.horizontal, 14)
                .padding(.vertical, 13)
                .background(inputBackground)
        }
    }

    private var dateField: some View {
        SheetFormField(label: lang.str(.habitDateField)) {
            HStack {
                DatePicker("", selection: $selectedDate, displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .tint(Makam.gold)
                    .environment(\.locale, lang.current.locale)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(inputBackground)
        }
    }

    private var timePeriodField: some View {
        SheetFormField(label: lang.str(.habitPeriodField)) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(TimePeriod.allCases, id: \.self) { period in
                        SelectionPill(
                            label: lang.timePeriodName(period),
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
        SheetFormField(label: lang.str(.habitDurationField)) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach([5, 10, 15, 20, 30, 45, 60, 90, 120], id: \.self) { mins in
                        SelectionPill(
                            label: lang.durationLabel(mins),
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
        SheetFormField(label: lang.str(.habitRepeatField)) {
            Menu {
                ForEach(RepeatFrequency.allCases, id: \.self) { freq in
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) { selectedRepeat = freq }
                    } label: {
                        if selectedRepeat == freq {
                            Label(lang.repeatLabel(freq), systemImage: "checkmark")
                        } else {
                            Text(lang.repeatLabel(freq))
                        }
                    }
                }
            } label: {
                HStack {
                    Text(lang.repeatLabel(selectedRepeat))
                        .font(.system(size: 14, design: .rounded))
                        .foregroundStyle(selectedRepeat == .none ? Makam.sandDim : Makam.gold)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Makam.sandDim)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 13)
                .background(inputBackground)
            }
        }
    }

    private var notesField: some View {
        SheetFormField(label: lang.str(.habitNotesField)) {
            ZStack(alignment: .topLeading) {
                if notes.isEmpty {
                    Text(lang.str(.habitNotesPlaceholder))
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
            Text(lang.str(.habitSave))
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
            repeatFrequency: selectedRepeat
        )
        dismiss()
    }
}

// MARK: - Reschedule Sheet

private struct RescheduleSheet: View {
    @EnvironmentObject var lang: LanguageManager
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
            Button(lang.str(.habitCancel)) { dismiss() }
                .font(.system(size: 15, design: .rounded))
                .foregroundStyle(Makam.sandDim)
            Spacer()
            Text(lang.str(.habitRescheduleTitle))
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(Makam.sand)
            Spacer()
            Button(lang.str(.habitPlanButton)) { save() }
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(Makam.gold)
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 16)
    }

    private var dateField: some View {
        SheetFormField(label: lang.str(.habitNewDate)) {
            HStack {
                DatePicker("", selection: $selectedDate, displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .tint(Makam.gold)
                    .environment(\.locale, lang.current.locale)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(inputBackground)
        }
    }

    private var timePeriodField: some View {
        SheetFormField(label: lang.str(.habitPeriodField)) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(TimePeriod.allCases, id: \.self) { period in
                        SelectionPill(
                            label: lang.timePeriodName(period),
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
            Text(lang.str(.habitPlanButton))
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
