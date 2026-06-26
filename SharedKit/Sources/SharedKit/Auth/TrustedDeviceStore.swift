import Foundation

/// Persists devices the user has approved so re-pairing is not needed on reconnect.
///
/// This default implementation is `UserDefaults`-backed for portability; production
/// builds should swap in a Keychain-backed store (planned for Phase 4) by conforming to
/// `TrustedDeviceStoring`.
public protocol TrustedDeviceStoring: Sendable {
    func trustedDevices() -> [DeviceInfo]
    func isTrusted(_ id: UUID) -> Bool
    func trust(_ device: DeviceInfo)
    func revoke(_ id: UUID)
}

public final class TrustedDeviceStore: TrustedDeviceStoring, @unchecked Sendable {
    private let defaults: UserDefaults
    private let key = "remotemac.trustedDevices"
    private let lock = NSLock()

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func trustedDevices() -> [DeviceInfo] {
        lock.lock(); defer { lock.unlock() }
        guard let data = defaults.data(forKey: key),
              let list = try? JSONDecoder().decode([DeviceInfo].self, from: data) else {
            return []
        }
        return list
    }

    public func isTrusted(_ id: UUID) -> Bool {
        trustedDevices().contains { $0.id == id }
    }

    public func trust(_ device: DeviceInfo) {
        lock.lock(); defer { lock.unlock() }
        var list = (try? JSONDecoder().decode([DeviceInfo].self,
                                               from: defaults.data(forKey: key) ?? Data())) ?? []
        list.removeAll { $0.id == device.id }
        list.append(device)
        if let data = try? JSONEncoder().encode(list) {
            defaults.set(data, forKey: key)
        }
    }

    public func revoke(_ id: UUID) {
        lock.lock(); defer { lock.unlock() }
        var list = trustedDevicesUnlocked()
        list.removeAll { $0.id == id }
        if let data = try? JSONEncoder().encode(list) {
            defaults.set(data, forKey: key)
        }
    }

    private func trustedDevicesUnlocked() -> [DeviceInfo] {
        guard let data = defaults.data(forKey: key),
              let list = try? JSONDecoder().decode([DeviceInfo].self, from: data) else {
            return []
        }
        return list
    }
}
