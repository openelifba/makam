// MARK: - QuranService.swift
// Calls Makam's own backend for Quran content. The backend owns all Quran
// Foundation API details — upstream URLs, access token, fixed query
// defaults — this app never talks to Quran Foundation directly.
//
// Routed through the shared NetworkClient (not a bare URLSession) so
// requests carry the same Authorization: Bearer token as the rest of the
// app's API calls — the gateway rejects unauthenticated /makam/api/* calls.

import Foundation

actor QuranService {
    static let shared = QuranService()

    /// Default reciter: Mishary Rashid Alafasy (id 7)
    static let defaultRecitationId = 7

    private let client = NetworkClient.shared

    private init() {}

    // MARK: - Public API

    func fetchChapters(language: String = "en") async throws -> [QuranChapter] {
        try await client.request(QuranChapterList.self, path: "/quran/chapters?language=\(language)").chapters
    }

    func fetchVerses(chapterId: Int, language: String = "en") async throws -> [QuranVerse] {
        try await client.request(
            QuranVerseList.self,
            path: "/quran/chapters/\(chapterId)/verses?language=\(language)"
        ).verses
    }

    func fetchRecitations() async throws -> [QuranRecitation] {
        try await client.request(QuranRecitationList.self, path: "/quran/recitations").recitations
    }

    func fetchAudioFiles(recitationId: Int, chapterId: Int) async throws -> [QuranAudioFile] {
        try await client.request(
            QuranAudioFiles.self,
            path: "/quran/recitations/\(recitationId)/chapters/\(chapterId)/audio"
        ).audioFiles
    }
}
