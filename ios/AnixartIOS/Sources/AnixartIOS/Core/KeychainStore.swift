import Foundation
import Security

enum KeychainStore {
    private static let service = "com.anixartios.app"
    private static let tokenAccount = "session-token"
    private static let profileIdAccount = "profile-id"

    static func getToken() -> String? {
        read(account: tokenAccount)
    }

    static func setToken(_ newValue: String?) {
        save(newValue, account: tokenAccount)
    }

    static func getProfileID() -> Int64? {
        guard let str = read(account: profileIdAccount) else { return nil }
        return Int64(str)
    }

    static func setProfileID(_ newValue: Int64?) {
        save(newValue.map(String.init), account: profileIdAccount)
    }

    static func clearSession() {
        setToken(nil)
        setProfileID(nil)
    }

    private static func read(account: String) -> String? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    private static func save(_ value: String?, account: String) {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ]
        SecItemDelete(query as CFDictionary)
        guard let value else { return }
        var item = query
        item[kSecValueData] = Data(value.utf8)
        item[kSecAttrAccessible] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(item as CFDictionary, nil)
    }
}
