// MARK: - HabitAPIClient.swift
// Thin shim that forwards calls to MakamAPI.
// HabitViewModel continues to reference HabitAPIClient.shared unchanged.

import Foundation

final class HabitAPIClient {
    static let shared = HabitAPIClient()
    private let api = MakamAPI.shared
    private init() {}

    func fetchTasks(date: String) async throws -> [HabitTask] {
        try await api.fetchTasks(date: date)
    }

    func create(
        title: String,
        date: String,
        timePeriod: TimePeriod,
        duration: Int,
        notes: String?,
        repeatFrequency: RepeatFrequency
    ) async throws -> [HabitTask] {
        try await api.createTask(
            title: title, date: date,
            timePeriod: timePeriod, duration: duration,
            notes: notes, repeatFrequency: repeatFrequency
        )
    }

    func update(_ task: HabitTask) async throws -> HabitTask {
        try await api.updateTask(task)
    }

    func toggleCompletion(id: String) async throws -> HabitTask {
        try await api.toggleCompletion(id: id)
    }

    func delete(id: String) async throws {
        try await api.deleteTask(id: id)
    }

    func deleteSeries(seriesId: String) async throws {
        try await api.deleteSeries(seriesId: seriesId)
    }
}
