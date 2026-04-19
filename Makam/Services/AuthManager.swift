// MARK: - AuthManager.swift
// Orchestrates the anonymous device-based auto-login flow.

import Foundation
#if canImport(UIKit)
import UIKit
#endif

actor AuthManager {
    static let shared = AuthManager()

    private let authService = AuthService()

    private init() {}

    // MARK: - Auto-Login

    /// Derives device credentials, registers (ignoring "already exists" errors),
    /// logs in, and stores the resulting JWT token in Keychain.
    func autoLoginWithDeviceId() async throws {
        let deviceId = await deviceId()
        let email    = "\(deviceId)@wordiam.com"
        let password = deviceId

        try? await authService.register(email: email, password: password)
        let token = try await authService.login(email: email, password: password)
        KeychainHelper.shared.save(token: token)
    }

    // MARK: - Device ID

    static let deviceIdKey = "makam.deviceId"

    static func cachedDeviceId() -> String? {
        UserDefaults.standard.string(forKey: deviceIdKey)
    }

    func deviceId() async -> String {
        if let cached = UserDefaults.standard.string(forKey: Self.deviceIdKey) { return cached }

        #if canImport(UIKit)
        let id = await MainActor.run {
            UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        }
        #else
        let id = UUID().uuidString
        #endif

        UserDefaults.standard.set(id, forKey: Self.deviceIdKey)
        return id
    }
}
