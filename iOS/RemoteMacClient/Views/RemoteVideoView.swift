import SwiftUI

#if canImport(WebRTC)
import WebRTC

/// Bridges the WebRTC `RTCMTLVideoView` (Metal-backed renderer) into SwiftUI so the
/// remote Mac screen can be displayed and overlaid with gesture handlers.
struct RemoteVideoView: UIViewRepresentable {
    let videoView: RTCMTLVideoView

    func makeUIView(context: Context) -> RTCMTLVideoView {
        videoView.videoContentMode = .scaleAspectFit
        videoView.backgroundColor = .black
        return videoView
    }
    func updateUIView(_ uiView: RTCMTLVideoView, context: Context) {}
}
#else
/// Placeholder shown before the WebRTC package is linked (keeps the UI compiling).
struct RemoteVideoView: View {
    var body: some View {
        ZStack {
            Color.black
            Text("WebRTC not linked—see docs/SETUP.md")
                .foregroundStyle(.secondary)
        }
    }
}
#endif
