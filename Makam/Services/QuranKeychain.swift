// MARK: - QuranKeychain.swift
// Persists the Quran Foundation session in Keychain as a JSON blob.
//
// Kept separate from the main app's auth token so signing out of one flow
// doesn't clobber the other. `kSecAttrAccessibleAfterFirstUnlock` lets the
// Widget read the same entry from the shared access group if we later need it.

import Foundation
import Security

final class QuranKeychain {
    static let shared = QuranKeychain()

    private let account = "quranSession"
    private let service = (Bundle.main.bundleIdentifier ?? "com.makam") + ".quran"

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private init() {
        encoder.dateEncodingStrategy = .secondsSince1970
        decoder.dateDecodingStrategy = .secondsSince1970
    }

    // MARK: - Read

    func load() -> QuranSession? {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecReturnData:  true,
            kSecMatchLimit:  kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return try? decoder.decode(QuranSession.self, from: data)
    }

    // MARK: - Write

    func save(_ session: QuranSession) {
        guard let data = try? encoder.encode(session) else { return }

        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ]
        let attributes: [CFString: Any] = [
            kSecValueData:       data,
            kSecAttrAccessible:  kSecAttrAccessibleAfterFirstUnlock
        ]

        if SecItemUpdate(query as CFDictionary, attributes as CFDictionary) == errSecItemNotFound {
            var newItem = query
            newItem[kSecValueData]      = data
            newItem[kSecAttrAccessible] = kSecAttrAccessibleAfterFirstUnlock
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
