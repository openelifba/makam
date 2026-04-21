// MARK: - VideoFeedService.swift
// Paginated feed client. All filtering + sync happens on the Makam backend.

import Foundation

// MARK: - Models

struct Video: Codable, Identifiable {
    let id: String
    let name: String
    let durationSeconds: Int?
    let thumbnailUrl: String?
    let streamUrl: String
}

struct VideoFeedPage: Codable {
    let items: [Video]
    let nextCursor: String?
}

// MARK: - Service

@MainActor
final class VideoFeedService: ObservableObject {

    @Published var items: [Video] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var nextCursor: String?
    private var hasMore = true
    private var isFetchingPage = false

    func loadFirstPage() async {
        items = []
        nextCursor = nil
        hasMore = true
        await loadNextPage()
    }

    func prefetchIfNearEnd(currentId: String, threshold: Int = 3) {
        guard let index = items.firstIndex(where: { $0.id == currentId }) else { return }
        if index >= items.count - threshold {
            Task { await loadNextPage() }
        }
    }

    func recordProgress(videoId: String, watchedSeconds: Int, durationSeconds: Int) async {
        try? await MakamAPI.shared.recordVideoProgress(
            videoId: videoId,
            watchedSeconds: watchedSeconds,
            durationSeconds: durationSeconds
        )
    }

    func setLiked(videoId: String, liked: Bool) async {
        try? await MakamAPI.shared.setVideoLike(videoId: videoId, liked: liked)
    }

    // MARK: - Private

    private func loadNextPage() async {
        guard hasMore, !isFetchingPage else { return }
        isFetchingPage = true
        if items.isEmpty { isLoading = true }
        errorMessage = nil
        defer {
            isFetchingPage = false
            isLoading = false
        }
        do {
            let page = try await MakamAPI.shared.fetchVideoFeed(cursor: nextCursor, limit: 20)
            items.append(contentsOf: page.items)
            nextCursor = page.nextCursor
            hasMore = page.nextCursor != nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
