import Foundation
import SharedKit

#if canImport(WebRTC)
import WebRTC
#endif

/// Client-side WebRTC transport: receives the host's video track, renders it, and sends
/// encrypted `ControlEvent`s over the reliable `control` data channel.
///
/// Guarded with `#if canImport(WebRTC)` so the module type-checks before the
/// stasel/WebRTC package is linked (see docs/SETUP.md).
public final class WebRTCClientTransport: NSObject {
    public var onStateChange: ((ClientConnectionState) -> Void)?
    public var onLatency: ((Int) -> Void)?
    public var onHostStatus: ((WireMessage.HostStatus) -> Void)?

    private let identity = DeviceIdentity.loadOrCreate(role: .client, name: ClientDevice.name)
    private var cryptoBox: CryptoBox?

    // Bonjour discovery used to return the answer SDP back to the advertising host.
    private let browser = BonjourBrowser()
    private var signaling: SignalingChannel?
    private var reconnect = ReconnectPolicy()

    /// Find the advertising host by name and send the answer SDP over the signaling
    /// channel, completing the handshake without a signaling server.
    public func returnAnswerToHost(_ answer: SessionDescriptor, hostName: String) {
        browser.onResults = { [weak self] results in
            guard let self else { return }
            for result in results {
                if case let .service(name, _, _, _) = result.endpoint, name == hostName {
                    let channel = self.browser.connect(to: result.endpoint)
                    self.signaling = channel
                    channel.send(.clientHello(self.identity.info))
                    channel.send(.answer(answer))
                    self.browser.stop()
                    return
                }
            }
        }
        browser.start()
    }

#if canImport(WebRTC)
    public let remoteVideoView = RTCMTLVideoView(frame: .zero)

    private static let factory: RTCPeerConnectionFactory = {
        RTCInitializeSSL()
        return RTCPeerConnectionFactory(
            encoderFactory: RTCDefaultVideoEncoderFactory(),
            decoderFactory: RTCDefaultVideoDecoderFactory())
    }()

    private var peerConnection: RTCPeerConnection?
    private var dataChannel: RTCDataChannel?
    private var remoteVideoTrack: RTCVideoTrack?
    private var latencyTimer: Timer?

    /// Apply the host's offer from the pairing payload, derive the session key, and
    /// produce an answer to return out-of-band.
    public func connect(using payload: PairingPayload) async throws -> SessionDescriptor {
        // Derive the E2EE session key from the host's public key + pairing salt.
        guard let hostKeyData = Data(base64Encoded: payload.host.publicKey) else {
            throw PairingError.malformedPayload
        }
        let hostKey = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: hostKeyData)
        cryptoBox = try CryptoBox(privateKey: identity.privateKey,
                                  peerPublicKey: hostKey, salt: payload.salt)

        let config = RTCConfiguration()
        config.iceServers = [RTCIceServer(urlStrings: ["stun:stun.l.google.com:19302"])]
        config.sdpSemantics = .unifiedPlan
        let constraints = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)
        let pc = Self.factory.peerConnection(with: config, constraints: constraints, delegate: self)!
        self.peerConnection = pc

        let offer = RTCSessionDescription(type: .offer, sdp: payload.offer.sdp)
        try await pc.setRemoteDescription(offer)
        let answer = try await pc.answer(for: constraints)
        try await pc.setLocalDescription(answer)
        return SessionDescriptor(kind: .answer, sdp: answer.sdp)
    }

    /// Encrypt and send a control event over the data channel.
    public func sendControl(_ event: ControlEvent) {
        guard let box = cryptoBox, let dc = dataChannel else { return }
        do {
            let plaintext = try WireCodec.encode(event)
            let sealed = try box.seal(plaintext)
            let data = try WireCodec.encode(WireMessage.control(sealed: sealed))
            dc.sendData(RTCDataBuffer(data: data, isBinary: true))
        } catch { /* drop on encode/seal failure */ }
    }

    public func close() {
        browser.stop()
        signaling?.close()
        latencyTimer?.invalidate(); latencyTimer = nil
        dataChannel?.close()
        peerConnection?.close()
        peerConnection = nil
        dataChannel = nil
        remoteVideoTrack = nil
    }

    private func startLatencyPings() {
        latencyTimer?.invalidate()
        latencyTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            guard let self, let dc = self.dataChannel,
                  let data = try? WireCodec.encode(WireMessage.ping(sentAt: Date())) else { return }
            dc.sendData(RTCDataBuffer(data: data, isBinary: true))
        }
    }

    private func handleInbound(_ data: Data) {
        guard let message = try? WireCodec.decode(WireMessage.self, from: data) else { return }
        switch message {
        case .pong(let sentAt):
            onLatency?(Int(Date().timeIntervalSince(sentAt) * 1000))
        case .ping(let sentAt):
            if let data = try? WireCodec.encode(WireMessage.pong(sentAt: sentAt)) {
                dataChannel?.sendData(RTCDataBuffer(data: data, isBinary: true))
            }
        case .hostStatus(let status):
            onHostStatus?(status)
        case .control:
            break // clients do not receive control events
        }
    }
#else
    public func connect(using payload: PairingPayload) async throws -> SessionDescriptor {
        throw TransportError.webRTCUnavailable
    }
    public func sendControl(_ event: ControlEvent) {}
    public func close() {}
#endif
}

public enum ClientDevice {
    public static var name: String {
#if canImport(UIKit)
        UIDevice.current.name
#else
        "iOS Device"
#endif
    }
}

#if canImport(UIKit)
import UIKit
#endif
import CryptoKit

#if canImport(WebRTC)
extension WebRTCClientTransport: RTCPeerConnectionDelegate {
    public func peerConnection(_ pc: RTCPeerConnection, didChange state: RTCIceConnectionState) {
        switch state {
        case .connected, .completed:
            onStateChange?(.connected); startLatencyPings()
        case .disconnected, .checking:
            onStateChange?(.reconnecting)
        case .failed:
            onStateChange?(.failed("ICE connection failed"))
        default: break
        }
    }
    public func peerConnection(_ pc: RTCPeerConnection, didAdd receiver: RTCRtpReceiver,
                               streams: [RTCMediaStream]) {
        if let track = receiver.track as? RTCVideoTrack {
            self.remoteVideoTrack = track
            track.add(remoteVideoView)
        }
    }
    public func peerConnection(_ pc: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {
        dataChannel.delegate = self
        self.dataChannel = dataChannel
    }
    public func peerConnection(_ pc: RTCPeerConnection, didChange s: RTCSignalingState) {}
    public func peerConnection(_ pc: RTCPeerConnection, didAdd stream: RTCMediaStream) {}
    public func peerConnection(_ pc: RTCPeerConnection, didRemove stream: RTCMediaStream) {}
    public func peerConnectionShouldNegotiate(_ pc: RTCPeerConnection) {}
    public func peerConnection(_ pc: RTCPeerConnection, didChange s: RTCIceGatheringState) {}
    public func peerConnection(_ pc: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {}
    public func peerConnection(_ pc: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {}
}

extension WebRTCClientTransport: RTCDataChannelDelegate {
    public func dataChannel(_ dc: RTCDataChannel, didReceiveMessageWith buffer: RTCDataBuffer) {
        handleInbound(buffer.data)
    }
    public func dataChannelDidChangeState(_ dc: RTCDataChannel) {}
}
#endif
