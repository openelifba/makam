import Foundation
import SwiftData

// MARK: - TaskRepository

/// Local-only repository for HabitTask CRUD operations backed by SwiftData.
///
/// Inject a `ModelContext` obtained from the SwiftData container:
/// ```swift
/// @Environment(\.modelContext) private var context
/// let repo = TaskRepository(context: context)
/// ```
@MainActor
final class TaskRepository {

    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    private static let isoFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    // MARK: - Create

    /// Inserts and persists a new HabitTask, returning the saved instance.
    @discardableResult
    func create(
        title: String,
        date: String,
        timePeriod: TimePeriod,
        duration: Int,
        notes: String? = nil,
        repeatFrequency: RepeatFrequency = .none
    ) throws -> HabitTask {
        let task = HabitTask(
            title: title,
            date: date,
            timePeriod: timePeriod,
            duration: duration,
            notes: notes,
            repeatFrequency: repeatFrequency
        )
        context.insert(task)
        try context.save()
        return task
    }

    /// Creates a series of recurring tasks starting from `date`.
    /// For `.none` and `.custom` a single task is created.
    func createWithRepeat(
        title: String,
        date: String,
        timePeriod: TimePeriod,
        duration: Int,
        notes: String? = nil,
        repeatFrequency: RepeatFrequency
    ) throws {
        guard let startDate = Self.isoFormatter.date(from: date) else { return }

        let cal = Calendar.current
        let offsets: [Int]
        let component: Calendar.Component

        switch repeatFrequency {
        case .none, .custom:
            let task = HabitTask(
                title: title, date: date, timePeriod: timePeriod,
                duration: duration, notes: notes, repeatFrequency: repeatFrequency
            )
            context.insert(task)
            try context.save()
            return
        case .daily:
            offsets = Array(0..<90)
            component = .day
        case .weekly:
            offsets = Array(0..<52)
            component = .weekOfYear
        case .monthly:
            offsets = Array(0..<12)
            component = .month
        case .yearly:
            offsets = Array(0..<2)
            component = .year
        }

        let seriesID = UUID().uuidString
        for offset in offsets {
            guard let d = cal.date(byAdding: component, value: offset, to: startDate) else { continue }
            let task = HabitTask(
                title: title,
                date: Self.isoFormatter.string(from: d),
                timePeriod: timePeriod,
                duration: duration,
                notes: notes,
                repeatFrequency: repeatFrequency,
                seriesID: seriesID
            )
            context.insert(task)
        }
        try context.save()
    }

    // MARK: - Read

    /// Returns all tasks for a given date, ordered by prayer-period sequence
    /// (İmsak → Güneş → Öğle → İkindi → Akşam → Yatsı).
    func tasks(for date: String) throws -> [HabitTask] {
        let predicate = #Predicate<HabitTask> { $0.date == date }
        let descriptor = FetchDescriptor<HabitTask>(predicate: predicate)
        let results = try context.fetch(descriptor)

        // Sort in-memory using the canonical TimePeriod.allCases order.
        let order = TimePeriod.allCases.map(\.rawValue)
        return results.sorted {
            let li = order.firstIndex(of: $0.timePeriod.rawValue) ?? Int.max
            let ri = order.firstIndex(of: $1.timePeriod.rawValue) ?? Int.max
            return li < ri
        }
    }

    /// Returns every stored task regardless of date, ordered by date then prayer period.
    func allTasks() throws -> [HabitTask] {
        let descriptor = FetchDescriptor<HabitTask>(
            sortBy: [SortDescriptor(\.date, order: .forward)]
        )
        let results = try context.fetch(descriptor)
        let order = TimePeriod.allCases.map(\.rawValue)
        return results.sorted {
            if $0.date != $1.date { return $0.date < $1.date }
            let li = order.firstIndex(of: $0.timePeriod.rawValue) ?? Int.max
            let ri = order.firstIndex(of: $1.timePeriod.rawValue) ?? Int.max
            return li < ri
        }
    }

    // MARK: - Update

    /// Updates the mutable fields of an existing task and persists the change.
    func update(
        _ task: HabitTask,
        title: String,
        date: String,
        timePeriod: TimePeriod,
        duration: Int,
        notes: String?,
        isCompleted: Bool,
        repeatFrequency: RepeatFrequency = .none
    ) throws {
        task.title           = title
        task.date            = date
        task.timePeriod      = timePeriod
        task.duration        = duration
        task.notes           = notes
        task.isCompleted     = isCompleted
        task.repeatFrequency = repeatFrequency
        try context.save()
    }

    /// Toggles the completion state of a task.
    func toggleCompletion(_ task: HabitTask) throws {
        task.isCompleted.toggle()
        try context.save()
    }

    // MARK: - Delete

    /// Removes a single task from the store.
    func delete(_ task: HabitTask) throws {
        context.delete(task)
        try context.save()
    }

    /// Removes all tasks for a given date.
    func deleteAll(for date: String) throws {
        let tasks = try tasks(for: date)
        tasks.forEach { context.delete($0) }
        try context.save()
    }

    /// Removes every task that belongs to the same repeat series.
    func deleteAllInSeries(seriesID: String) throws {
        let predicate = #Predicate<HabitTask> { $0.seriesID == seriesID }
        let descriptor = FetchDescriptor<HabitTask>(predicate: predicate)
        let tasks = try context.fetch(descriptor)
        tasks.forEach { context.delete($0) }
        try context.save()
    }
}
