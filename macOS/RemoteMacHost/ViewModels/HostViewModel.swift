import Foundation
import Combine
import CoreImage
import SharedKit

/// Connection lifecycle states surfaced to the UI.
public enum HostConnectionState: Equatable {
    case idle
    case advertising      // waiting for a client to pair / connect
    case connecting
    case connected
    case reconnecting
    case failed(String)
}

/// Coordinates capture, transport and input for the host (MVVM ViewModel).
///
/// The view model is deliberately UI-framework agnostic apart from `@Published`
/// properties; all heavy lifting is delegated to the injected services so each can be
/// unit-tested in isolation.
@MainActor
public final class HostViewModel: ObservableObject {
    // MARK: Published UI state
    @Published public private(set) var state: HostConnectionState = .idle
    @Published public private(set) var latencyMillis: Int?
    @Published public private(set) var pairingQRPayload: String?
    @Published public private(set) var authString: String?
    @Published public var encoder: VideoEncoder = .h264

    // MARK: Services (injected for testability)
    private let capture: ScreenCaptureService
    private let transport: WebRTCHostTransport
    private let input: InputInjector
    private let permissions: PermissionsManager
    private let trustedStore: TrustedDeviceStoring

    private var cancellables = Set<AnyCancellable>()

    public init(capture: ScreenCaptureService = ScreenCaptureService(),
                transport: WebRTCHostTransport = WebRTCHostTransport(),
                input: InputInjector = InputInjector(),
                permissions: PermissionsManager = PermissionsManager(),
                trustedStore: TrustedDeviceStoring = TrustedDeviceStore()) {
        self.capture = capture
        self.transport = transport
        self.input = input
        self.permissions = permissions
        self.trustedStore = trustedStore
        wireTransport()
    }

    // MARK: Intent

    /// Begin advertising: verify permissions, start capture, create a WebRTC offer and
    /// render it (plus the host identity) as a pairing QR.
    public func startHosting() async {
        do {
            try await permissions.ensureScreenRecording()
            permissions.ensureAccessibility() // user-driven; warns if not granted
            state = .advertising

            try await capture.start(encoder: encoder) { [weak self] frame in
                self?.transport.pushVideoFrame(frame)
            }
            let offer = try await transport.makeOffer()
            let payload = try transport.makePairingPayload(offer: offer)
            pairingQRPayload = try payload.encodedForQR()
            authString = payload.authString
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    /// Apply a scanned/received answer from the client to complete the handshake.
    public func acceptAnswer(_ descriptor: SessionDescriptor) async {
        do {
            state = .connecting
            try await transport.acceptAnswer(descriptor)
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    /// Start advertising over Bonjour so the client can return its answer SDP without a
    /// signaling server. The host applies the answer automatically when it arrives.
    public func startDiscovery() {
        transport.startAdvertising { [weak self] answer in
            Task { await self?.acceptAnswer(answer) }
        }
    }

    public func stopHosting() {
        capture.stop()
        transport.close()
        state = .idle
        pairingQRPayload = nil
        latencyMillis = nil
    }

    // MARK: Wiring

    private func wireTransport() {
        // Decrypted control events from the client are injected as native input.
        transport.onControlEvent = { [weak self] event in
            self?.input.inject(event)
        }
        transport.onStateChange = { [weak self] newState in
            Task { @MainActor in self?.state = newState }
        }
        transport.onLatency = { [weak self] millis in
            Task { @MainActor in self?.latencyMillis = millis }
        }
    }
}
