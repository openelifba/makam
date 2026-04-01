import Foundation

// MARK: - HabitViewModel

@MainActor
final class HabitViewModel: ObservableObject {
    @Published var tasks: [HabitTask] = []
    @Published private(set) var isLoading = false

    /// The date string currently displayed in the habit timeline (yyyy-MM-dd).
    @Published var currentDate: String = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: .now)
    }()

    private let api = HabitAPIClient.shared

    private static let isoFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    // MARK: - Fetch

    func fetchTasks(for date: String) {
        currentDate = date
        Task {
            isLoading = true
            do {
                tasks = try await api.fetchTasks(date: date)
            } catch {}
            isLoading = false
        }
    }

    // MARK: - Create

    func create(
        title: String,
        date: String,
        timePeriod: TimePeriod,
        duration: Int,
        notes: String?,
        repeatFrequency: RepeatFrequency
    ) {
        Task {
            do {
                _ = try await api.create(
                    title: title, date: date,
                    timePeriod: timePeriod, duration: duration,
                    notes: notes, repeatFrequency: repeatFrequency
                )
                fetchTasks(for: currentDate)
            } catch {}
        }
    }

    // MARK: - Update

    func update(_ task: HabitTask) {
        Task {
            do {
                let updated = try await api.update(task)
                if let idx = tasks.firstIndex(where: { $0.id == updated.id }) {
                    tasks[idx] = updated
                } else {
                    fetchTasks(for: currentDate)
                }
            } catch {}
        }
    }

    // MARK: - Toggle Completion

    func toggleCompletion(_ task: HabitTask) {
        Task {
            do {
                let updated = try await api.toggleCompletion(id: task.id)
                if let idx = tasks.firstIndex(where: { $0.id == updated.id }) {
                    tasks[idx] = updated
                }
            } catch {}
        }
    }

    // MARK: - Delete

    func delete(_ task: HabitTask) {
        tasks.removeAll { $0.id == task.id }
        Task {
            do { try await api.delete(id: task.id) } catch {
                fetchTasks(for: currentDate) // revert on failure
            }
        }
    }

    func deleteSeries(seriesId: String) {
        tasks.removeAll { $0.seriesID == seriesId }
        Task {
            do { try await api.deleteSeries(seriesId: seriesId) } catch {
                fetchTasks(for: currentDate)
            }
        }
    }

    // MARK: - Copy

    func copy(_ task: HabitTask) {
        create(
            title: task.title, date: task.date,
            timePeriod: task.timePeriod, duration: task.duration,
            notes: task.notes, repeatFrequency: task.repeatFrequency
        )
    }

    // MARK: - Reschedule

    func reschedule(_ task: HabitTask, to newDate: String, period: TimePeriod) {
        var updated = task
        updated.date = newDate
        updated.timePeriod = period
        update(updated)
    }

    func rescheduleToTomorrow(_ task: HabitTask) {
        guard let d = Self.isoFormatter.date(from: task.date),
              let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: d)
        else { return }
        reschedule(task, to: Self.isoFormatter.string(from: tomorrow), period: task.timePeriod)
    }
}
