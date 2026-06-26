import Foundation
import ScreenCaptureKit
import CoreMedia
import CoreVideo

/// Supported video codecs for the outbound stream.
public enum VideoEncoder: String, CaseIterable, Identifiable, Sendable {
    case h264 = "H.264"
    case hevc = "HEVC"
    public var id: String { rawValue }
}

/// Captures the main display with **ScreenCaptureKit** and forwards each frame to a
/// sink (the WebRTC transport) as a `CapturedFrame`.
///
/// ScreenCaptureKit delivers `CMSampleBuffer`s on a background queue; we extract the
/// `CVPixelBuffer` and hand it off without copying. The transport converts it into an
/// `RTCVideoFrame` (see `WebRTCHostTransport.pushVideoFrame`).
public final class ScreenCaptureService: NSObject, SCStreamOutput, @unchecked Sendable {
    /// A captured frame plus the timing/geometry the transport needs.
    public struct CapturedFrame: @unchecked Sendable {
        public let pixelBuffer: CVPixelBuffer
        public let presentationTime: CMTime
        public let width: Int
        public let height: Int
    }

    private var stream: SCStream?
    private let outputQueue = DispatchQueue(label: "remotemac.capture.output")
    private var frameSink: ((CapturedFrame) -> Void)?

    /// Start capturing the main display at up to 60 fps.
    /// - Parameter onFrame: called on a background queue for every captured frame.
    public func start(encoder: VideoEncoder,
                      onFrame: @escaping (CapturedFrame) -> Void) async throws {
        self.frameSink = onFrame

        let content = try await SCShareableContent.excludingDesktopWindows(
            false, onScreenWindowsOnly: true)
        guard let display = content.displays.first else {
            throw CaptureError.noDisplay
        }

        let filter = SCContentFilter(display: display, excludingWindows: [])
        let config = SCStreamConfiguration()
        config.width = display.width
        config.height = display.height
        config.minimumFrameInterval = CMTime(value: 1, timescale: 60)
        config.queueDepth = 5
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.showsCursor = true

        let stream = SCStream(filter: filter, configuration: config, delegate: nil)
        try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: outputQueue)
        try await stream.startCapture()
        self.stream = stream
    }

    public func stop() {
        stream?.stopCapture { _ in }
        stream = nil
        frameSink = nil
    }

    // MARK: SCStreamOutput

    public func stream(_ stream: SCStream,
                       didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
                       of type: SCStreamOutputType) {
        guard type == .screen,
              CMSampleBufferGetNumSamples(sampleBuffer) > 0,
              sampleBuffer.isValid,
              let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        // Drop frames flagged as not-complete/idle by ScreenCaptureKit.
        if let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer,
                                                                     createIfNecessary: false)
            as? [[SCStreamFrameInfo: Any]],
           let statusRaw = attachments.first?[.status] as? Int,
           let status = SCFrameStatus(rawValue: statusRaw),
           status != .complete {
            return
        }
        let frame = CapturedFrame(
            pixelBuffer: pixelBuffer,
            presentationTime: CMSampleBufferGetPresentationTimeStamp(sampleBuffer),
            width: CVPixelBufferGetWidth(pixelBuffer),
            height: CVPixelBufferGetHeight(pixelBuffer)
        )
        frameSink?(frame)
    }
}

public enum CaptureError: Error, LocalizedError {
    case noDisplay
    public var errorDescription: String? {
        switch self {
        case .noDisplay: return "No capturable display was found."
        }
    }
}
