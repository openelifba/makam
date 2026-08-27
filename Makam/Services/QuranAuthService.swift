// MARK: - QuranAuthService.swift
// OAuth2 Authorization Code + PKCE + OpenID Connect flow for the
// Quran Foundation User APIs.
//
// The iOS client:
//   1. Generates code_verifier, code_challenge, state, and nonce locally.
//   2. Opens the hosted /oauth2/auth page in an ASWebAuthenticationSession.
//   3. Receives the `code` on our custom redirect URI.
//   4. Validates the `state` round-trip, then POSTs `{code, codeVerifier,
//      redirectUri}` to the Makam backend /api/quran/auth/exchange.
//   5. The backend is the confidential client — it holds CLIENT_SECRET and
//      calls the Quran Foundation token endpoint over HTTP Basic auth.
//   6. This client stores access_token + refresh_token + id_token in
//      Keychain and validates the `nonce` claim on the id_token.
//   7. On expiry, we ask the backend to refresh by posting the refresh_token.
//
// Security note: CLIENT_SECRET never lives in the app bundle.

import Foundation
import AuthenticationServices
import CommonCrypto
#if canImport(UIKit)
import UIKit
#endif

@MainActor
final class QuranAuthService: NSObject, ObservableObject {
    static let shared = QuranAuthService()

    // MARK: - Published state

    @Published private(set) var session: QuranSession?
    @Published private(set) var isSigningIn = false
    @Published private(set) var lastError: String?

    var isSignedIn: Bool { session != nil }

    // MARK: - Config

    // The hosted authorize URL; the matching /oauth2/token exchange is done
    // server-side. See the Quran Foundation docs for prelive vs production.
    private let authorizeURL  = "https://prelive-oauth2.quran.foundation/oauth2/auth"
    private let clientId      = "d8ce625b-7d9e-434e-996d-b0b17555f391"

    // Quran Foundation rejects custom URL scheme redirect URIs ("unsafe or
    // unsupported scheme"), so the value we send them is an HTTPS URL backed
    // by a relay endpoint on our own backend (see QuranAuthController#callback),
    // which 302s straight to the custom scheme below. ASWebAuthenticationSession
    // intercepts that second hop before it ever loads, so callback parsing is
    // unaffected — only the redirect_uri we advertise to the auth server changes.
    //
    // Registered as a CFBundleURLSchemes entry in Info.plist so the system
    // routes the final callback back to ASWebAuthenticationSession.
    static let redirectURIScheme = "com.yaysoftwares.makam"
    static let redirectURI       = "\(Endpoints.makam)/quran/auth/callback"

    // Scopes: `openid` + `offline_access` unlock id_token + refresh_token.
    // The rest are Quran Foundation User API namespaces.
    private let scopes = [
        "openid",
        "offline_access",
        "bookmark",
        "collection",
        "reading_session",
        "preference"
    ]

    // MARK: - State held only for the in-flight login

    private var pendingState: String?
    private var pendingNonce: String?
    private var pendingVerifier: String?
    private var webAuthSession: ASWebAuthenticationSession?

    // MARK: - Init

    private override init() {
        super.init()
        session = QuranKeychain.shared.load()
    }

    // MARK: - Login

    func signIn() async {
        guard !isSigningIn else { return }
        isSigningIn = true
        lastError = nil
        defer { isSigningIn = false }

        do {
            let verifier  = Self.randomURLSafe(length: 64)
            let challenge = Self.codeChallenge(from: verifier)
            let state     = Self.randomURLSafe(length: 32)
            let nonce     = Self.randomURLSafe(length: 32)

            pendingVerifier = verifier
            pendingState    = state
            pendingNonce    = nonce

            let callback = try await presentAuthSession(state: state, challenge: challenge, nonce: nonce)
            let code = try validateStateAndExtractCode(from: callback, expectedState: state)
            try await exchangeCodeAndPersist(code: code, verifier: verifier, nonce: nonce)
        } catch {
            lastError = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
        }

        pendingVerifier = nil
        pendingState    = nil
        pendingNonce    = nil
    }

    func signOut() {
        QuranKeychain.shared.delete()
        session = nil
    }

    // MARK: - Token access (used by QuranService)

    /// Returns a valid access token, refreshing via the backend if needed.
    /// Throws if the user is not signed in.
    func accessToken() async throws -> String {
        guard var current = session else { throw QuranAuthError.notSignedIn }

        // Refresh 60 s before actual expiry to avoid using a stale token.
        if Date() < current.expiresAt.addingTimeInterval(-60) {
            return current.accessToken
        }

        guard let refresh = current.refreshToken else { throw QuranAuthError.notSignedIn }

        let fresh = try await postRefresh(refreshToken: refresh)
        current = apply(fresh, onto: current)
        QuranKeychain.shared.save(current)
        session = current
        return current.accessToken
    }

    var clientIdForHeaders: String { clientId }

    // MARK: - Presenting the hosted login page

    private func presentAuthSession(state: String, challenge: String, nonce: String) async throws -> URL {
        var components = URLComponents(string: authorizeURL)
        components?.queryItems = [
            URLQueryItem(name: "response_type",        value: "code"),
            URLQueryItem(name: "client_id",            value: clientId),
            URLQueryItem(name: "redirect_uri",         value: Self.redirectURI),
            URLQueryItem(name: "scope",                value: scopes.joined(separator: " ")),
            URLQueryItem(name: "state",                value: state),
            URLQueryItem(name: "nonce",                value: nonce),
            URLQueryItem(name: "code_challenge",       value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256")
        ]
        guard let url = components?.url else { throw QuranAuthError.invalidAuthorizeURL }

        return try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: Self.redirectURIScheme
            ) { callback, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let callback else {
                    continuation.resume(throwing: QuranAuthError.cancelled)
                    return
                }
                continuation.resume(returning: callback)
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            self.webAuthSession = session
            _ = session.start()
        }
    }

    // MARK: - Callback parsing

    private func validateStateAndExtractCode(from url: URL, expectedState: String) throws -> String {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let items = components.queryItems else {
            throw QuranAuthError.invalidCallback
        }

        if let err = items.first(where: { $0.name == "error" })?.value {
            let desc = items.first(where: { $0.name == "error_description" })?.value
            throw QuranAuthError.server("\(err): \(desc ?? "no description")")
        }

        guard let returnedState = items.first(where: { $0.name == "state" })?.value,
              returnedState == expectedState else {
            throw QuranAuthError.stateMismatch
        }

        guard let code = items.first(where: { $0.name == "code" })?.value, !code.isEmpty else {
            throw QuranAuthError.invalidCallback
        }

        return code
    }

    // MARK: - Code exchange + nonce validation

    private func exchangeCodeAndPersist(code: String, verifier: String, nonce: String) async throws {
        let response = try await postExchange(code: code, verifier: verifier)

        if let idToken = response.idToken {
            try validateNonce(idToken: idToken, expected: nonce)
        }

        let claims = response.idToken.flatMap(Self.decodeIdTokenClaims)
        let session = QuranSession(
            accessToken:  response.accessToken,
            refreshToken: response.refreshToken,
            idToken:      response.idToken,
            expiresAt:    Date().addingTimeInterval(TimeInterval(response.expiresIn)),
            sub:          claims?["sub"] as? String,
            email:        claims?["email"] as? String,
            firstName:    claims?["first_name"] as? String,
            lastName:     claims?["last_name"] as? String
        )
        QuranKeychain.shared.save(session)
        self.session = session
    }

    private func validateNonce(idToken: String, expected: String) throws {
        guard let claims = Self.decodeIdTokenClaims(idToken),
              let returned = claims["nonce"] as? String else {
            // id_token without a nonce claim: Quran Foundation may omit it if
            // we don't request `openid`, so only fail if the claim is present.
            return
        }
        if returned != expected { throw QuranAuthError.nonceMismatch }
    }

    // MARK: - Backend calls

    private func postExchange(code: String, verifier: String) async throws -> QuranTokenResponse {
        let body = QuranTokenExchangeRequest(
            code: code,
            codeVerifier: verifier,
            redirectUri: Self.redirectURI
        )
        return try await postJSON(
            path: "/quran/auth/exchange",
            body: body
        )
    }

    private func postRefresh(refreshToken: String) async throws -> QuranTokenResponse {
        let body = QuranTokenRefreshRequest(refreshToken: refreshToken)
        return try await postJSON(
            path: "/quran/auth/refresh",
            body: body
        )
    }

    private func postJSON<Body: Encodable>(path: String, body: Body) async throws -> QuranTokenResponse {
        guard let url = URL(string: Endpoints.makam + path) else { throw URLError(.badURL) }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        if !(200..<300).contains(http.statusCode) {
            let payload = String(data: data, encoding: .utf8) ?? ""
            throw QuranAuthError.server("HTTP \(http.statusCode): \(payload)")
        }
        return try JSONDecoder().decode(QuranTokenResponse.self, from: data)
    }

    private func apply(_ fresh: QuranTokenResponse, onto old: QuranSession) -> QuranSession {
        var updated = old
        updated.accessToken  = fresh.accessToken
        updated.refreshToken = fresh.refreshToken ?? old.refreshToken
        updated.idToken      = fresh.idToken ?? old.idToken
        updated.expiresAt    = Date().addingTimeInterval(TimeInterval(fresh.expiresIn))
        if let idToken = fresh.idToken, let claims = Self.decodeIdTokenClaims(idToken) {
            updated.sub       = (claims["sub"] as? String) ?? old.sub
            updated.email     = (claims["email"] as? String) ?? old.email
            updated.firstName = (claims["first_name"] as? String) ?? old.firstName
            updated.lastName  = (claims["last_name"] as? String) ?? old.lastName
        }
        return updated
    }

    // MARK: - PKCE + JWT helpers

    private static func randomURLSafe(length: Int) -> String {
        var bytes = [UInt8](repeating: 0, count: length)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64URLEncoded()
    }

    private static func codeChallenge(from verifier: String) -> String {
        let data = Data(verifier.utf8)
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes { _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &hash) }
        return Data(hash).base64URLEncoded()
    }

    /// Best-effort JWT payload decode. We never *trust* these claims for
    /// authorization — the access_token is the authority — but we do read
    /// `nonce` (to validate), `sub` (to identify the user locally) and the
    /// optional `email`/`first_name`/`last_name` for display.
    private static func decodeIdTokenClaims(_ idToken: String) -> [String: Any]? {
        let parts = idToken.split(separator: ".")
        guard parts.count >= 2 else { return nil }
        let payload = String(parts[1])
        guard let data = Data.fromBase64URL(payload),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return json
    }
}

// MARK: - ASWebAuthenticationPresentationContextProviding

extension QuranAuthService: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        #if canImport(UIKit)
        let scenes = UIApplication.shared.connectedScenes
        for scene in scenes {
            if let windowScene = scene as? UIWindowScene,
               let window = windowScene.windows.first(where: { $0.isKeyWindow }) ?? windowScene.windows.first {
                return window
            }
        }
        return ASPresentationAnchor()
        #else
        return ASPresentationAnchor()
        #endif
    }
}

// MARK: - Errors

enum QuranAuthError: LocalizedError {
    case notSignedIn
    case cancelled
    case invalidAuthorizeURL
    case invalidCallback
    case stateMismatch
    case nonceMismatch
    case server(String)

    var errorDescription: String? {
        switch self {
        case .notSignedIn:          return "You are not signed in to the Quran Foundation."
        case .cancelled:            return "Sign-in was cancelled."
        case .invalidAuthorizeURL:  return "Could not build the authorization URL."
        case .invalidCallback:      return "The sign-in callback was missing an authorization code."
        case .stateMismatch:        return "Sign-in failed a CSRF check (state mismatch)."
        case .nonceMismatch:        return "Sign-in failed a replay check (nonce mismatch)."
        case .server(let detail):   return "Server error: \(detail)"
        }
    }
}

// MARK: - Private base64url utilities

private extension Data {
    func base64URLEncoded() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    static func fromBase64URL(_ input: String) -> Data? {
        var s = input
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while s.count % 4 != 0 { s.append("=") }
        return Data(base64Encoded: s)
    }
}

