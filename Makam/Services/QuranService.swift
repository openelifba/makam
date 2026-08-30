// MARK: - QuranService.swift
// OAuth2 client-credentials flow + Quran Foundation content API.
//
// Token is cached in-memory and refreshed automatically 60s before expiry.
// All methods are isolated to the actor so the token refresh is race-free.

import Foundation

actor QuranService {
    static let shared = QuranService()

    // MARK: - Constants

    private let oauthBase    = "https://prelive-oauth2.quran.foundation"
    private let clientId     = "d8ce625b-7d9e-434e-996d-b0b17555f391"
    private let clientSecret = "H~Et8xgS.bgciJEpuKEhM4UkiW"
    private let contentBase  = "https://api.qurancdn.com/api/qdc"

    /// Default translation: Saheeh International (English, resource id 131)
    static let defaultTranslationId = 131
    /// Default reciter: Mishary Rashid Alafasy (id 7)
    static let defaultRecitationId  = 7

    // MARK: - Token cache

    private var cachedToken: String?
    private var tokenExpiry: Date = .distantPast

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
        let token = try await accessToken()
        let url   = try makeURL("\(contentBase)/chapters", query: ["language": language])
        return try await get(QuranChapterList.self, url: url, token: token).chapters
    }

    /// Fetches all verses for a chapter in one request (per_page=286 covers the longest chapter).
    func fetchVerses(chapterId: Int, language: String = "en") async throws -> [QuranVerse] {
        let token = try await accessToken()
        let url   = try makeURL(
            "\(contentBase)/verses/by_chapter/\(chapterId)",
            query: [
                "language":    language,
                "words":       "false",
                "translations": "\(Self.defaultTranslationId)",
                "per_page":    "286",
                "page":        "1"
            ]
        )
        return try await get(QuranVerseList.self, url: url, token: token).verses
    }

    func fetchRecitations() async throws -> [QuranRecitation] {
        let token = try await accessToken()
        let url   = try makeURL("\(contentBase)/resources/recitations")
        return try await get(QuranRecitationList.self, url: url, token: token).recitations
    }

    func fetchAudioFiles(recitationId: Int, chapterId: Int) async throws -> [QuranAudioFile] {
        let token = try await accessToken()
        let url   = try makeURL("\(contentBase)/recitations/\(recitationId)/by_chapter/\(chapterId)")
        return try await get(QuranAudioFiles.self, url: url, token: token).audioFiles
    }

    // MARK: - Token management

    private func accessToken() async throws -> String {
        if let token = cachedToken, Date() < tokenExpiry { return token }
        return try await refreshToken()
    }

    private func refreshToken() async throws -> String {
        guard let url = URL(string: "\(oauthBase)/oauth/token") else { throw URLError(.badURL) }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        var components = URLComponents()
        components.queryItems = [
            URLQueryItem(name: "grant_type",    value: "client_credentials"),
            URLQueryItem(name: "client_id",     value: clientId),
            URLQueryItem(name: "client_secret", value: clientSecret)
        ]
        req.httpBody = components.query?.data(using: .utf8)

        let (data, response) = try await session.data(for: req)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }

        let tokenResponse = try decoder.decode(QuranToken.self, from: data)
        cachedToken = tokenResponse.accessToken
        // Refresh 60 s before actual expiry to avoid using a stale token
        tokenExpiry = Date().addingTimeInterval(TimeInterval(max(tokenResponse.expiresIn - 60, 0)))
        return tokenResponse.accessToken
    }

    // MARK: - Helpers

    private func get<T: Decodable>(_ type: T.Type, url: URL, token: String) async throws -> T {
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, _) = try await session.data(for: req)
        return try decoder.decode(T.self, from: data)
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
