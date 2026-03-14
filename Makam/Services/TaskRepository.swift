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

    // MARK: - Create

    /// Inserts and persists a new HabitTask, returning the saved instance.
    @discardableResult
    func create(
        title: String,
        date: String,
        timePeriod: TimePeriod,
        duration: Int,
        notes: String? = nil,
        repeatRule: RepeatRule = .none,
        repeatInterval: Int = 1
    ) throws -> HabitTask {
        let task = HabitTask(
            title: title,
            date: date,
            timePeriod: timePeriod,
            duration: duration,
            notes: notes,
            repeatRule: repeatRule,
            repeatInterval: repeatInterval
        )
        context.insert(task)
        try context.save()
        return task
    }

    /// Inserts the task for the starting date plus all future occurrences
    /// determined by `repeatRule`. Returns the first (anchor) task.
    @discardableResult
    func createRepeating(
        title: String,
        startDate: Date,
        timePeriod: TimePeriod,
        duration: Int,
        notes: String?,
        repeatRule: RepeatRule,
        repeatInterval: Int = 1
    ) throws -> HabitTask {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        let dates = occurrenceDates(
            from: startDate,
            rule: repeatRule,
            interval: repeatInterval,
            calendar: calendar
        )

        var first: HabitTask?
        for date in dates {
            let task = HabitTask(
                title: title,
                date: formatter.string(from: date),
                timePeriod: timePeriod,
                duration: duration,
                notes: notes,
                repeatRule: repeatRule,
                repeatInterval: repeatInterval
            )
            context.insert(task)
            if first == nil { first = task }
        }
        try context.save()
        return first!
    }

    // MARK: - Repeat Helpers

    private func occurrenceDates(
        from start: Date,
        rule: RepeatRule,
        interval: Int,
        calendar: Calendar
    ) -> [Date] {
        switch rule {
        case .none:
            return [start]
        case .daily:
            return (0..<365).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
        case .weekly:
            return (0..<52).compactMap { calendar.date(byAdding: .weekOfYear, value: $0, to: start) }
        case .monthly:
            return (0..<12).compactMap { calendar.date(byAdding: .month, value: $0, to: start) }
        case .yearly:
            return (0..<3).compactMap { calendar.date(byAdding: .year, value: $0, to: start) }
        case .custom:
            let safeInterval = max(1, interval)
            let count = max(1, 365 / safeInterval)
            return (0..<count).compactMap {
                calendar.date(byAdding: .day, value: $0 * safeInterval, to: start)
            }
        }
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
        repeatRule: RepeatRule = .none,
        repeatInterval: Int = 1
    ) throws {
        task.title          = title
        task.date           = date
        task.timePeriod     = timePeriod
        task.duration       = duration
        task.notes          = notes
        task.isCompleted    = isCompleted
        task.repeatRule     = repeatRule
        task.repeatInterval = repeatInterval
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
}
