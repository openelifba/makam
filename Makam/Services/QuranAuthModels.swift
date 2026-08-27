// MARK: - QuranAuthModels.swift
// DTOs shared between QuranAuthService and the Makam backend.
//
// The backend mirrors the Quran Foundation /oauth2/token response so field
// names match RFC 6749 (snake_case on the wire, camelCase in Swift).

import Foundation

struct QuranTokenExchangeRequest: Encodable {
    let code: String
    let codeVerifier: String
    let redirectUri: String
}

struct QuranTokenRefreshRequest: Encodable {
    let refreshToken: String
}

struct QuranTokenResponse: Decodable {
    let accessToken: String
    let tokenType: String?
    let expiresIn: Int
    let refreshToken: String?
    let idToken: String?
    let scope: String?

    enum CodingKeys: String, CodingKey {
        case accessToken  = "access_token"
        case tokenType    = "token_type"
        case expiresIn    = "expires_in"
        case refreshToken = "refresh_token"
        case idToken      = "id_token"
        case scope
    }
}

/// Persisted locally in Keychain; represents the active user session.
struct QuranSession: Codable, Equatable {
    var accessToken: String
    var refreshToken: String?
    var idToken: String?
    var expiresAt: Date
    var sub: String?
    var email: String?
    var firstName: String?
    var lastName: String?
}
