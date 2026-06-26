import Foundation
import SharedKit
#if canImport(WebRTC)
import WebRTC
#endif

/// Host-side WebRTC transport: publishes the captured video track and exchanges
/// encrypted `ControlEvent`s over a reliable data channel.
///
/// The WebRTC binary is provided by the `stasel/WebRTC` SwiftPM package (see
/// docs/SETUP.md). The code is guarded with `#if canImport(WebRTC)` so the rest of the
/// host module still type-checks before the dependency is added.
public final class WebRTCHostTransport: NSObject {
    // Callbacks consumed by the view model.
    public var onControlEvent: ((ControlEvent) -> Void)?
    public var onStateChange: ((HostConnectionState) -> Void)?
    public var onLatency: ((Int) -> Void)?

    private let identity = DeviceIdentity.loadOrCreate(role: .host, name: Host.machineName)
    private var cryptoBox: CryptoBox?
    private var sessionSalt = CryptoBox.randomSalt()

    // Bonjour-based signaling side-channel for returning the client's answer SDP.
    private let advertiser = BonjourAdvertiser()
    private var signaling: SignalingChannel?

    /// Advertise on the LAN; `onAnswer` fires when the client returns its answer.
    public func startAdvertising(onAnswer: @escaping (SessionDescriptor) -> Void) {
        advertiser.onClientConnected = { [weak self] channel in
            self?.signaling = channel
            channel.onMessage = { message in
                if case .answer(let descriptor) = message { onAnswer(descriptor) }
            }
        }
        try? advertiser.start(name: identity.info.name)
    }

#if canImport(WebRTC)
    private static let factory: RTCPeerConnectionFactory = {
        RTCInitializeSSL()
        let encoder = RTCDefaultVideoEncoderFactory()
        let decoder = RTCDefaultVideoDecoderFactory()
        return RTCPeerConnectionFactory(encoderFactory: encoder, decoderFactory: decoder)
    }()

    private var peerConnection: RTCPeerConnection?
    private var videoSource: RTCVideoSource?
    private var videoCapturerAdapter: RTCVideoCapturer?
    private var dataChannel: RTCDataChannel?

    /// Build the peer connection, attach a video track backed by an `RTCVideoSource`,
    /// and open the control data channel.
    private func makePeerConnection() -> RTCPeerConnection {
        let config = RTCConfiguration()
        // LAN-first: peers are usually on the same subnet, so a STUN server is enough
        // to gather server-reflexive candidates when needed.
        config.iceServers = [RTCIceServer(urlStrings: ["stun:stun.l.google.com:19302"])]
        config.sdpSemantics = .unifiedPlan

        let constraints = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)
        let pc = Self.factory.peerConnection(with: config, constraints: constraints, delegate: self)!

        let source = Self.factory.videoSource()
        self.videoSource = source
        self.videoCapturerAdapter = RTCVideoCapturer(delegate: source)
        let track = Self.factory.videoTrack(with: source, trackId: "screen0")
        pc.add(track, streamIds: ["stream0"])

        let dcConfig = RTCDataChannelConfiguration()
        dcConfig.isOrdered = true
        if let dc = pc.dataChannel(forLabel: "control", configuration: dcConfig) {
            dc.delegate = self
            self.dataChannel = dc
        }
        return pc
    }

    public func makeOffer() async throws -> SessionDescriptor {
        let pc = makePeerConnection()
        self.peerConnection = pc
        let constraints = RTCMediaConstraints(
            mandatoryConstraints: ["OfferToReceiveVideo": "false"],
            optionalConstraints: nil)
        let offer = try await pc.offer(for: constraints)
        try await pc.setLocalDescription(offer)
        return SessionDescriptor(kind: .offer, sdp: offer.sdp)
    }

    public func acceptAnswer(_ descriptor: SessionDescriptor) async throws {
        let sdp = RTCSessionDescription(type: .answer, sdp: descriptor.sdp)
        try await peerConnection?.setRemoteDescription(sdp)
    }

    /// Convert a captured `CVPixelBuffer` into an `RTCVideoFrame` and feed the source.
    public func pushVideoFrame(_ frame: ScreenCaptureService.CapturedFrame) {
        guard let capturer = videoCapturerAdapter, let source = videoSource else { return }
        let buffer = RTCCVPixelBuffer(pixelBuffer: frame.pixelBuffer)
        let timestampNs = Int64(CMTimeGetSeconds(frame.presentationTime) * Double(NSEC_PER_SEC))
        let rtcFrame = RTCVideoFrame(buffer: buffer, rotation: ._0, timeStampNs: timestampNs)
        source.capturer(capturer, didCapture: rtcFrame)
    }

    public func close() {
        advertiser.stop()
        signaling?.close()
        dataChannel?.close()
        peerConnection?.close()
        peerConnection = nil
        dataChannel = nil
    }
#else
    // Fallbacks so the module compiles before the WebRTC package is added.
    public func makeOffer() async throws -> SessionDescriptor {
        throw TransportError.webRTCUnavailable
    }
    public func acceptAnswer(_ descriptor: SessionDescriptor) async throws {
        throw TransportError.webRTCUnavailable
    }
    public func pushVideoFrame(_ frame: ScreenCaptureService.CapturedFrame) {}
    public func close() {}
#endif

    /// Build the pairing payload (host identity + salt + offer + anti-MITM auth string).
    public func makePairingPayload(offer: SessionDescriptor) throws -> PairingPayload {
        let authString = PairingPayload.makeAuthString(
            hostPublicKey: identity.publicKeyData,
            clientPublicKey: Data(),   // filled in once the client key is known
            salt: sessionSalt)
        return PairingPayload(host: identity.info, salt: sessionSalt,
                              offer: offer, authString: authString)
    }

    /// Decrypt and decode an inbound control message, then surface it.
    fileprivate func handleInbound(_ data: Data) {
        do {
            let message = try WireCodec.decode(WireMessage.self, from: data)
            switch message {
            case .control(let sealed):
                guard let box = cryptoBox else { return }
                let plaintext = try box.open(sealed)
                let event = try WireCodec.decode(ControlEvent.self, from: plaintext)
                onControlEvent?(event)
            case .ping(let sentAt):
                send(.pong(sentAt: sentAt))
            case .pong(let sentAt):
                onLatency?(Int(Date().timeIntervalSince(sentAt) * 1000))
            case .hostStatus:
                break
            }
        } catch {
            // Malformed/undecryptable frames are dropped (untrusted input).
        }
    }

    private func send(_ message: WireMessage) {
#if canImport(WebRTC)
        guard let data = try? WireCodec.encode(message) else { return }
        dataChannel?.sendData(RTCDataBuffer(data: data, isBinary: true))
#endif
    }
}

public enum TransportError: Error, LocalizedError {
    case webRTCUnavailable
    public var errorDescription: String? {
        switch self {
        case .webRTCUnavailable:
            return "WebRTC is not linked. Add the stasel/WebRTC package (see docs/SETUP.md)."
        }
    }
}

#if canImport(WebRTC)
extension WebRTCHostTransport: RTCPeerConnectionDelegate {
    public func peerConnection(_ pc: RTCPeerConnection, didChange state: RTCIceConnectionState) {
        switch state {
        case .connected, .completed: onStateChange?(.connected)
        case .disconnected, .checking: onStateChange?(.reconnecting)
        case .failed: onStateChange?(.failed("ICE connection failed"))
        default: break
        }
    }
    public func peerConnection(_ pc: RTCPeerConnection, didChange s: RTCSignalingState) {}
    public func peerConnection(_ pc: RTCPeerConnection, didAdd stream: RTCMediaStream) {}
    public func peerConnection(_ pc: RTCPeerConnection, didRemove stream: RTCMediaStream) {}
    public func peerConnectionShouldNegotiate(_ pc: RTCPeerConnection) {}
    public func peerConnection(_ pc: RTCPeerConnection, didChange s: RTCIceGatheringState) {}
    public func peerConnection(_ pc: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {}
    public func peerConnection(_ pc: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {}
    public func peerConnection(_ pc: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {
        dataChannel.delegate = self
        self.dataChannel = dataChannel
    }
}

extension WebRTCHostTransport: RTCDataChannelDelegate {
    public func dataChannel(_ dc: RTCDataChannel, didReceiveMessageWith buffer: RTCDataBuffer) {
        handleInbound(buffer.data)
    }
    public func dataChannelDidChangeState(_ dc: RTCDataChannel) {}
}
#endif
