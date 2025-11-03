import Foundation
import Security

actor KeychainStore {
    enum Key: String, CaseIterable {
        case apiKey
        case accessToken
        case refreshToken
        case tokenExpiry
    }

    private let service = "com.example.NewDashboard.credentials"

    func value(for key: Key) -> String? {
        var query: [String: Any] = baseQuery(for: key)
        query[kSecReturnData as String] = kCFBooleanTrue
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func set(_ value: String?, for key: Key) {
        var query: [String: Any] = baseQuery(for: key)
        if let value {
            let data = Data(value.utf8)
            let updateStatus = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
            if updateStatus == errSecItemNotFound {
                query[kSecValueData as String] = data
                SecItemAdd(query as CFDictionary, nil)
            }
        } else {
            SecItemDelete(query as CFDictionary)
        }
    }

    func removeAll() {
        for key in Key.allCases {
            SecItemDelete(baseQuery(for: key) as CFDictionary)
        }
    }

    private func baseQuery(for key: Key) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
    }
}
