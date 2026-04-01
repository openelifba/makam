// MARK: - NetworkClient.swift
// Shared URLSession wrapper for the Makam backend.
//
// Responsibilities:
//  - Attaches Authorization: Bearer <token> to every request.
//  - On 401: triggers auto-login once then retries.
//  - Actor isolation ensures the refresh flag is race-free.

import Foundation

// MARK: - NetworkError

enum NetworkError: LocalizedError {
    case invalidResponse
    case http(Int)
    case unauthorized

    var errorDescription: String? {
        switch self {
        case .invalidResponse:    return "Invalid server response."
        case .http(let code):     return "HTTP error \(code)."
        case .unauthorized:       return "Authentication failed."
        }
    }
}

// MARK: - NetworkClient

actor NetworkClient {
    static let shared = NetworkClient()

    private let session: URLSession
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    /// Guard against concurrent refresh races. While `true`, a refresh is already
    /// in flight; any concurrent 401 propagates `.unauthorized` immediately.
    private var isRefreshing = false

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest  = Endpoints.connectTimeoutSeconds
        config.timeoutIntervalForResource = Endpoints.receiveTimeoutSeconds
        session = URLSession(configuration: config)
    }

    // MARK: - Public — typed responses

    func request<T: Decodable>(_ type: T.Type, path: String, method: String = "GET", body: (any Encodable)? = nil) async throws -> T {
        let data = try await send(path: path, method: method, body: body)
        return try decoder.decode(T.self, from: data)
    }

    // MARK: - Public — no response body (DELETE, PATCH with no return, etc.)

    func requestVoid(path: String, method: String, body: (any Encodable)? = nil) async throws {
        _ = try await send(path: path, method: method, body: body)
    }

    // MARK: - Private — core send + 401 retry

    private func send(
        path: String,
        method: String,
        body: (any Encodable)? = nil,
        isRetry: Bool = false
    ) async throws -> Data {
        let req = try buildRequest(path: path, method: method, body: body)
        let (data, response) = try await session.data(for: req)

        guard let http = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        if http.statusCode == 401, !isRetry {
            guard !isRefreshing else { throw NetworkError.unauthorized }
            isRefreshing = true
            defer { isRefreshing = false }
            try await AuthManager.shared.autoLoginWithDeviceId()
            return try await send(path: path, method: method, body: body, isRetry: true)
        }

        guard (200..<300).contains(http.statusCode) else {
            throw NetworkError.http(http.statusCode)
        }

        return data
    }

    // MARK: - Private — request builder

    private func buildRequest(path: String, method: String, body: (any Encodable)? = nil) throws -> URLRequest {
        guard let url = URL(string: Endpoints.makam + path) else { throw URLError(.badURL) }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token = KeychainHelper.shared.token {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let body {
            req.httpBody = try encoder.encode(body)
        }
        return req
    }
}
