// MARK: - AuthService.swift
// Unauthenticated calls to the shared auth service.
// Does NOT use NetworkClient — no bearer token attached.

import Foundation

final class AuthService {

    private let session: URLSession
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest  = Endpoints.connectTimeoutSeconds
        config.timeoutIntervalForResource = Endpoints.receiveTimeoutSeconds
        session = URLSession(configuration: config)
    }

    // MARK: - Register (POST /auth/api/auth/register)
    // Returns 204 No Content on success; errors are ignored by callers
    // (the user may already be registered).

    func register(email: String, password: String) async throws {
        struct Body: Encodable { let email: String; let password: String }
        let req = try buildRequest(
            path: "/auth/register",
            body: Body(email: email, password: password)
        )
        let (_, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) || http.statusCode == 409
        else { return } // treat all non-fatal — caller uses try?
    }

    // MARK: - Login (POST /auth/api/auth/login)
    // Returns the JWT token string.

    func login(email: String, password: String) async throws -> String {
        struct Body: Encodable { let email: String; let password: String }
        struct Response: Decodable { let token: String }

        let req = try buildRequest(
            path: "/auth/login",
            body: Body(email: email, password: password)
        )
        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode)
        else { throw AuthError.loginFailed }

        return try decoder.decode(Response.self, from: data).token
    }

    // MARK: - Private

    private func buildRequest(path: String, body: some Encodable) throws -> URLRequest {
        guard let url = URL(string: Endpoints.auth + path) else { throw URLError(.badURL) }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.httpBody = try encoder.encode(body)
        return req
    }
}

// MARK: - AuthError

enum AuthError: LocalizedError {
    case loginFailed

    var errorDescription: String? {
        switch self {
        case .loginFailed: return "Login failed. Check credentials and try again."
        }
    }
}
