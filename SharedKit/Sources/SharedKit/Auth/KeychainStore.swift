import Foundation
import Security

/// A small wrapper over the iOS/macOS **Keychain** for storing secrets (the device's
/// long-term private key) and the trusted-device list. This replaces the
/// `UserDefaults`-backed stores used in earlier phases for anything sensitive.
public struct KeychainStore: Sendable {
    private let service: String

    public init(service: String = "com.example.remotemac") {
        self.service = service
    }

    public func set(_ data: Data, for account: String) {
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(base as CFDictionary)
        var add = base
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(add as CFDictionary, nil)
    }

    public func get(_ account: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess else {
            return nil
        }
        return result as? Data
    }

    public func delete(_ account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}

/// Keychain-backed implementation of `TrustedDeviceStoring` for production use.
public final class KeychainTrustedDeviceStore: TrustedDeviceStoring, @unchecked Sendable {
    private let keychain: KeychainStore
    private let account = "trustedDevices"
    private let lock = NSLock()

    public init(keychain: KeychainStore = KeychainStore()) {
        self.keychain = keychain
    }

    public func trustedDevices() -> [DeviceInfo] {
        guard let data = keychain.get(account),
              let list = try? JSONDecoder().decode([DeviceInfo].self, from: data) else { return [] }
        return list
    }

    public func isTrusted(_ id: UUID) -> Bool {
        trustedDevices().contains { $0.id == id }
    }

    public func trust(_ device: DeviceInfo) {
        lock.lock(); defer { lock.unlock() }
        var list = trustedDevices()
        list.removeAll { $0.id == device.id }
        list.append(device)
        if let data = try? JSONEncoder().encode(list) { keychain.set(data, for: account) }
    }

    public func revoke(_ id: UUID) {
        lock.lock(); defer { lock.unlock() }
        var list = trustedDevices()
        list.removeAll { $0.id == id }
        if let data = try? JSONEncoder().encode(list) { keychain.set(data, for: account) }
    }
}
