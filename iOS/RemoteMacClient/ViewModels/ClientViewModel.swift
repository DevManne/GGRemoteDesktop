import Foundation
import Combine
import SharedKit

#if canImport(WebRTC)
import WebRTC
#endif

/// Connection lifecycle states surfaced to the client UI.
public enum ClientConnectionState: Equatable {
    case disconnected
    case scanning
    case connecting
    case connected
    case reconnecting
    case failed(String)
}

/// Orchestrates QR pairing, WebRTC transport and input forwarding for the client
/// (MVVM ViewModel). UI-agnostic apart from `@Published` state; services are injected.
@MainActor
public final class ClientViewModel: ObservableObject {
    @Published public private(set) var state: ClientConnectionState = .disconnected
    @Published public private(set) var latencyMillis: Int?
    @Published public private(set) var authString: String?
    /// Host display geometry, used to keep the gesture mapper's aspect ratio correct.
    @Published public private(set) var hostStatus: WireMessage.HostStatus?

    private let transport: WebRTCClientTransport
    private let trustedStore: TrustedDeviceStoring

    public let gestureMapper = GestureMapper()

    public init(transport: WebRTCClientTransport = WebRTCClientTransport(),
                trustedStore: TrustedDeviceStoring = TrustedDeviceStore()) {
        self.transport = transport
        self.trustedStore = trustedStore
        wire()
        gestureMapper.onEvent = { [weak self] event in
            self?.transport.sendControl(event)
        }
    }

#if canImport(WebRTC)
    /// The renderer view backing the remote video track (created by the transport).
    public var remoteVideoView: RTCMTLVideoView { transport.remoteVideoView }
#endif

    // MARK: Intent

    public func beginScanning() { state = .scanning }

    /// Handle a decoded pairing QR: verify, derive keys, set the remote offer, create an
    /// answer, and trust the host. The answer is returned to the host (QR/Bonjour in
    /// Phase 4).
    public func handleScannedPayload(_ raw: String) async {
        do {
            let payload = try PairingPayload.decodeFromQR(raw)
            authString = payload.authString
            state = .connecting
            let answer = try await transport.connect(using: payload)
            trustedStore.trust(payload.host)
            lastAnswer = answer
            // Return the answer to the host over the Bonjour signaling channel.
            transport.returnAnswerToHost(answer, hostName: payload.host.name)
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    public func disconnect() {
        transport.close()
        state = .disconnected
        latencyMillis = nil
        authString = nil
    }

    /// Forward text typed on the iOS keyboard to the host.
    public func sendText(_ text: String) {
        transport.sendControl(.text(text))
    }

    public func sendKey(_ keyCode: UInt16, modifiers: KeyModifiers, down: Bool) {
        transport.sendControl(down ? .keyDown(keyCode: keyCode, modifiers: modifiers)
                                   : .keyUp(keyCode: keyCode, modifiers: modifiers))
    }

    /// The most recent answer descriptor (returned to host out-of-band in Phase 4).
    public private(set) var lastAnswer: SessionDescriptor?

    // MARK: Wiring

    private func wire() {
        transport.onStateChange = { [weak self] newState in
            Task { @MainActor in self?.state = newState }
        }
        transport.onLatency = { [weak self] millis in
            Task { @MainActor in self?.latencyMillis = millis }
        }
        transport.onHostStatus = { [weak self] status in
            Task { @MainActor in
                self?.hostStatus = status
                self?.gestureMapper.hostAspectRatio =
                    Double(status.displayWidth) / Double(status.displayHeight)
            }
        }
    }
}
