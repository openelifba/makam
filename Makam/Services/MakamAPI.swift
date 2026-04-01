// MARK: - MakamAPI.swift
// Typed API client for the Makam backend service.
// All calls route through NetworkClient (auth + retry handled there).

import Foundation

final class MakamAPI {
    static let shared = MakamAPI()

    private let client = NetworkClient.shared
    private let encoder = JSONEncoder()

    private init() {}

    // MARK: - Habits

    func fetchTasks(date: String) async throws -> [HabitTask] {
        try await client.request([HabitTask].self, path: "/habits?date=\(date)")
    }

    func createTask(
        title: String,
        date: String,
        timePeriod: TimePeriod,
        duration: Int,
        notes: String?,
        repeatFrequency: RepeatFrequency
    ) async throws -> [HabitTask] {
        struct Body: Encodable {
            let title: String
            let date: String
            let timePeriod: String
            let duration: Int
            let notes: String?
            let repeatFrequency: String
        }
        let body = Body(
            title: title, date: date,
            timePeriod: timePeriod.rawValue,
            duration: duration, notes: notes,
            repeatFrequency: repeatFrequency.rawValue
        )
        return try await client.request([HabitTask].self, path: "/habits", method: "POST", body: body)
    }

    func updateTask(_ task: HabitTask) async throws -> HabitTask {
        struct Body: Encodable {
            let title: String
            let date: String
            let timePeriod: String
            let duration: Int
            let notes: String?
            let isCompleted: Bool
            let repeatFrequency: String
        }
        let body = Body(
            title: task.title, date: task.date,
            timePeriod: task.timePeriod.rawValue,
            duration: task.duration, notes: task.notes,
            isCompleted: task.isCompleted,
            repeatFrequency: task.repeatFrequency.rawValue
        )
        return try await client.request(HabitTask.self, path: "/habits/\(task.id)", method: "PUT", body: body)
    }

    func toggleCompletion(id: String) async throws -> HabitTask {
        try await client.request(HabitTask.self, path: "/habits/\(id)/completion", method: "PATCH")
    }

    func deleteTask(id: String) async throws {
        try await client.requestVoid(path: "/habits/\(id)", method: "DELETE")
    }

    func deleteSeries(seriesId: String) async throws {
        try await client.requestVoid(path: "/habits/series/\(seriesId)", method: "DELETE")
    }

    // TODO: Add additional Makam service endpoints here as the backend exposes them.
}
