import Foundation

// MARK: - TaskRepository

/// Local-only repository for HabitTask CRUD operations backed by HabitStore.
///
/// Usage:
/// ```swift
/// @EnvironmentObject var store: HabitStore
/// let repo = TaskRepository(store: store)
/// ```
@MainActor
final class TaskRepository {

    private let store: HabitStore

    init(store: HabitStore) {
        self.store = store
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
    ) -> HabitTask {
        let task = HabitTask(
            title: title,
            date: date,
            timePeriod: timePeriod,
            duration: duration,
            notes: notes,
            repeatFrequency: repeatFrequency
        )
        store.insert(task)
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
    ) {
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
            store.insert(task)
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
            store.insert(task)
        }
    }

    // MARK: - Read

    /// Returns all tasks for a given date, ordered by prayer-period sequence.
    func tasks(for date: String) -> [HabitTask] {
        store.tasks(for: date)
    }

    /// Returns every stored task regardless of date, ordered by date then prayer period.
    func allTasks() -> [HabitTask] {
        store.allTasks()
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
    ) {
        var updated = task
        updated.title           = title
        updated.date            = date
        updated.timePeriod      = timePeriod
        updated.duration        = duration
        updated.notes           = notes
        updated.isCompleted     = isCompleted
        updated.repeatFrequency = repeatFrequency
        store.update(updated)
    }

    /// Toggles the completion state of a task.
    func toggleCompletion(_ task: HabitTask) {
        var updated = task
        updated.isCompleted.toggle()
        store.update(updated)
    }

    // MARK: - Delete

    /// Removes a single task from the store.
    func delete(_ task: HabitTask) {
        store.delete(id: task.id)
    }

    /// Removes all tasks for a given date.
    func deleteAll(for date: String) {
        store.deleteAll(for: date)
    }

    /// Removes every task that belongs to the same repeat series.
    func deleteAllInSeries(seriesID: String) {
        store.deleteAllInSeries(seriesID: seriesID)
    }
}
