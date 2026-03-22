import Foundation
import Combine

// MARK: - HabitStore

/// Observable store that holds all HabitTask objects and persists them as JSON.
/// Replaces SwiftData so the app supports iOS 15+.
final class HabitStore: ObservableObject {
    @Published private(set) var tasks: [HabitTask] = []

    private static let fileName = "habit_tasks.json"

    private static var storageURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent(fileName)
    }

    init() {
        load()
    }

    // MARK: - Query

    func tasks(for date: String) -> [HabitTask] {
        let order = TimePeriod.allCases.map(\.rawValue)
        return tasks
            .filter { $0.date == date }
            .sorted {
                let li = order.firstIndex(of: $0.timePeriod.rawValue) ?? Int.max
                let ri = order.firstIndex(of: $1.timePeriod.rawValue) ?? Int.max
                return li < ri
            }
    }

    func allTasks() -> [HabitTask] {
        let order = TimePeriod.allCases.map(\.rawValue)
        return tasks.sorted {
            if $0.date != $1.date { return $0.date < $1.date }
            let li = order.firstIndex(of: $0.timePeriod.rawValue) ?? Int.max
            let ri = order.firstIndex(of: $1.timePeriod.rawValue) ?? Int.max
            return li < ri
        }
    }

    // MARK: - Mutations

    func insert(_ task: HabitTask) {
        tasks.append(task)
        persist()
    }

    func update(_ updated: HabitTask) {
        guard let idx = tasks.firstIndex(where: { $0.id == updated.id }) else { return }
        tasks[idx] = updated
        persist()
    }

    func delete(id: String) {
        tasks.removeAll { $0.id == id }
        persist()
    }

    func deleteAll(for date: String) {
        tasks.removeAll { $0.date == date }
        persist()
    }

    func deleteAllInSeries(seriesID: String) {
        tasks.removeAll { $0.seriesID == seriesID }
        persist()
    }

    // MARK: - Persistence

    private func persist() {
        do {
            let data = try JSONEncoder().encode(tasks)
            try data.write(to: Self.storageURL, options: .atomic)
        } catch {
            print("[HabitStore] save error: \(error)")
        }
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: Self.storageURL.path) else { return }
        do {
            let data = try Data(contentsOf: Self.storageURL)
            tasks = try JSONDecoder().decode([HabitTask].self, from: data)
        } catch {
            print("[HabitStore] load error: \(error)")
            tasks = []
        }
    }
}
