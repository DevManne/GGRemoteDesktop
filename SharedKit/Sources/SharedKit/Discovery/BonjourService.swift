import Foundation
import Network

/// Local-network discovery + a TCP signaling side-channel using **Bonjour** (Network
/// framework). Because there is no signaling server, the host advertises a service the
/// client browses for; once a connection is established it is used to return the answer
/// SDP and trickle ICE candidates that the QR alone cannot carry.
///
/// Service type: `_remotemac._tcp` (must match Info.plist `NSBonjourServices`).
public enum Bonjour {
    public static let serviceType = "_remotemac._tcp"
    public static let domain = "local."
}

/// Advertises the host on the LAN and accepts a single client signaling connection.
public final class BonjourAdvertiser {
    private var listener: NWListener?
    private let queue = DispatchQueue(label: "remotemac.bonjour.advertiser")

    /// Called when a client connects; the returned channel carries signaling messages.
    public var onClientConnected: ((SignalingChannel) -> Void)?

    public init() {}

    /// Begin advertising under `name` (e.g. the host device name).
    public func start(name: String) throws {
        let params = NWParameters.tcp
        params.includePeerToPeer = true
        let listener = try NWListener(using: params)
        listener.service = NWListener.Service(name: name, type: Bonjour.serviceType,
                                              domain: Bonjour.domain)
        listener.newConnectionHandler = { [weak self] connection in
            connection.start(queue: self?.queue ?? .main)
            let channel = SignalingChannel(connection: connection)
            self?.onClientConnected?(channel)
        }
        listener.start(queue: queue)
        self.listener = listener
    }

    public func stop() {
        listener?.cancel()
        listener = nil
    }
}

/// Browses for hosts on the LAN and connects to a chosen one.
public final class BonjourBrowser {
    private var browser: NWBrowser?
    private let queue = DispatchQueue(label: "remotemac.bonjour.browser")

    /// Called with the current set of discovered host endpoints.
    public var onResults: (([NWBrowser.Result]) -> Void)?

    public init() {}

    public func start() {
        let params = NWParameters.tcp
        params.includePeerToPeer = true
        let descriptor = NWBrowser.Descriptor.bonjour(type: Bonjour.serviceType,
                                                      domain: Bonjour.domain)
        let browser = NWBrowser(for: descriptor, using: params)
        browser.browseResultsChangedHandler = { [weak self] results, _ in
            self?.onResults?(Array(results))
        }
        browser.start(queue: queue)
        self.browser = browser
    }

    /// Open a signaling channel to a discovered endpoint.
    public func connect(to endpoint: NWEndpoint) -> SignalingChannel {
        let connection = NWConnection(to: endpoint, using: .tcp)
        connection.start(queue: queue)
        return SignalingChannel(connection: connection)
    }

    public func stop() {
        browser?.cancel()
        browser = nil
    }
}
