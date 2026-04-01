// MARK: - KeychainHelper.swift
// Stores and retrieves the JWT bearer token from Keychain.

import Foundation
import Security

final class KeychainHelper {
    static let shared = KeychainHelper()

    private let account = "authToken"
    private let service = Bundle.main.bundleIdentifier ?? "com.makam"

    private init() {}

    // MARK: - Read

    var token: String? {
        let query: [CFString: Any] = [
            kSecClass:            kSecClassGenericPassword,
            kSecAttrService:      service,
            kSecAttrAccount:      account,
            kSecReturnData:       true,
            kSecMatchLimit:       kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8)
        else { return nil }
        return string
    }

    // MARK: - Write

    func save(token: String) {
        guard let data = token.data(using: .utf8) else { return }

        // Try update first; if item doesn't exist, add it.
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ]
        let attributes: [CFString: Any] = [kSecValueData: data]

        if SecItemUpdate(query as CFDictionary, attributes as CFDictionary) == errSecItemNotFound {
            var newItem = query
            newItem[kSecValueData] = data
            SecItemAdd(newItem as CFDictionary, nil)
        }
    }

    // MARK: - Delete

    func delete() {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}
