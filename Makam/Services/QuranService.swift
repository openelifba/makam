// MARK: - QuranService.swift
// Calls the Quran Foundation content + user APIs using the access_token
// obtained through the OAuth2 Authorization Code + PKCE + OIDC flow
// (see QuranAuthService). CLIENT_SECRET is never embedded in the app —
// the backend performs the /token exchanges on behalf of the client.
//
// The API expects two headers on every request:
//   x-auth-token:  <user access_token>
//   x-client-id:   <public OAuth2 client id>
//
// QuranAuthService handles expiry + refresh; this service just asks for a
// valid access token before each call.

import Foundation

actor QuranService {
    static let shared = QuranService()

    // MARK: - Constants

    private let contentBase  = "https://apis-prelive.quran.foundation/content/api/v4"

    /// Default translation: Saheeh International (English, resource id 131)
    static let defaultTranslationId = 131
    /// Default reciter: Mishary Rashid Alafasy (id 7)
    static let defaultRecitationId  = 7

    // MARK: - URLSession

    private let session: URLSession
    private let decoder: JSONDecoder

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest  = 30
        config.timeoutIntervalForResource = 60
        session = URLSession(configuration: config)
        decoder = JSONDecoder()
    }

    // MARK: - Public API

    func fetchChapters(language: String = "en") async throws -> [QuranChapter] {
        let url = try makeURL("\(contentBase)/chapters", query: ["language": language])
        return try await get(QuranChapterList.self, url: url).chapters
    }

    /// Fetches all verses for a chapter in one request (per_page=286 covers the longest chapter).
    func fetchVerses(chapterId: Int, language: String = "en") async throws -> [QuranVerse] {
        let url = try makeURL(
            "\(contentBase)/verses/by_chapter/\(chapterId)",
            query: [
                "language":           language,
                "words":              "false",
                "translations":       "\(Self.defaultTranslationId)",
                "fields":             "text_uthmani",
                "translation_fields": "text",
                "per_page":           "286",
                "page":               "1"
            ]
        )
        return try await get(QuranVerseList.self, url: url).verses
    }

    func fetchRecitations() async throws -> [QuranRecitation] {
        let url = try makeURL("\(contentBase)/resources/recitations")
        return try await get(QuranRecitationList.self, url: url).recitations
    }

    func fetchAudioFiles(recitationId: Int, chapterId: Int) async throws -> [QuranAudioFile] {
        let url = try makeURL("\(contentBase)/recitations/\(recitationId)/by_chapter/\(chapterId)")
        return try await get(QuranAudioFiles.self, url: url).audioFiles
    }

    // MARK: - Helpers

    private func get<T: Decodable>(_ type: T.Type, url: URL) async throws -> T {
        let (token, clientId) = try await authHeaders()

        var req = URLRequest(url: url)
        req.setValue(token, forHTTPHeaderField: "x-auth-token")
        req.setValue(clientId, forHTTPHeaderField: "x-client-id")
        req.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: req)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }
        return try decoder.decode(T.self, from: data)
    }

    private func authHeaders() async throws -> (token: String, clientId: String) {
        let token = try await QuranAuthService.shared.accessToken()
        let clientId = await QuranAuthService.shared.clientIdForHeaders
        return (token, clientId)
    }

    private func makeURL(_ string: String, query: [String: String] = [:]) throws -> URL {
        var components = URLComponents(string: string)
        if !query.isEmpty {
            components?.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        guard let url = components?.url else { throw URLError(.badURL) }
        return url
    }
}
