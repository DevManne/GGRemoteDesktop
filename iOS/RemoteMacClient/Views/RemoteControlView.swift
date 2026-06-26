import SwiftUI

/// The live control surface: renders the remote Mac screen and maps multi-touch
/// gestures to control events via the view model's `GestureMapper`.
///
/// Gesture vocabulary:
/// - one-finger drag        → move cursor
/// - one-finger tap         → left click
/// - two-finger tap         → right click
/// - double tap             → double click
/// - long-press then drag   → drag & drop
/// - two-finger drag        → scroll
struct RemoteControlView: View {
    @EnvironmentObject private var viewModel: ClientViewModel
    @State private var showKeyboard = false
    @State private var typed = ""

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            ZStack(alignment: .top) {
                RemoteVideoView(videoView: viewModelVideoView)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .gesture(moveGesture(size: size))
                    .gesture(dragGesture(size: size))
                    .simultaneousGesture(scrollGesture(size: size))
                    .gesture(TapGesture(count: 2).onEnded { _ in
                        viewModel.gestureMapper.doubleTap(at: lastPoint, in: size)
                    })
                    .gesture(TapGesture().onEnded {
                        viewModel.gestureMapper.tap(at: lastPoint, in: size)
                    })
                    .gesture(TapGesture(count: 1)
                        .modifiers(.control)
                        .onEnded { viewModel.gestureMapper.twoFingerTap(at: lastPoint, in: size) })

                statusBar
            }
            .overlay(alignment: .bottomTrailing) { keyboardButton }
        }
        .background(.black)
        .sheet(isPresented: $showKeyboard) { keyboardSheet }
    }

    // Tracks the most recent touch location for tap gestures.
    @State private var lastPoint: CGPoint = .zero

#if canImport(WebRTC)
    private var viewModelVideoView: RTCMTLVideoView { viewModel.remoteVideoView }
#endif

    private var statusBar: some View {
        HStack {
            Label(statusText, systemImage: "dot.radiowaves.left.and.right")
            Spacer()
            if let latency = viewModel.latencyMillis {
                Text("\(latency) ms").monospacedDigit()
            }
            Button("Disconnect", role: .destructive) { viewModel.disconnect() }
                .buttonStyle(.bordered)
        }
        .font(.footnote)
        .padding(8)
        .background(.ultraThinMaterial)
    }

    private var keyboardButton: some View {
        Button {
            showKeyboard = true
        } label: {
            Image(systemName: "keyboard")
                .font(.title2)
                .padding(14)
                .background(.ultraThinMaterial, in: Circle())
        }
        .padding(20)
    }

    private var keyboardSheet: some View {
        VStack(spacing: 16) {
            Text("Remote Keyboard").font(.headline)
            TextField("Type to send to Mac", text: $typed)
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()
                .onChange(of: typed) { _, newValue in
                    if let last = newValue.last {
                        viewModel.sendText(String(last))
                    }
                }
            Button("Done") { showKeyboard = false; typed = "" }
                .buttonStyle(.borderedProminent)
            Spacer()
        }
        .padding()
        .presentationDetents([.height(200)])
    }

    private var statusText: String {
        switch viewModel.state {
        case .connected: return "Connected"
        case .reconnecting: return "Reconnecting…"
        default: return ""
        }
    }

    // MARK: Gestures

    private func moveGesture(size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                lastPoint = value.location
                viewModel.gestureMapper.move(to: value.location, in: size)
            }
    }

    private func dragGesture(size: CGSize) -> some Gesture {
        LongPressGesture(minimumDuration: 0.4)
            .sequenced(before: DragGesture(minimumDistance: 0))
            .onChanged { value in
                switch value {
                case .second(true, let drag?):
                    viewModel.gestureMapper.dragMove(to: drag.location, in: size)
                default:
                    break
                }
            }
            .onEnded { value in
                if case .second(true, let drag?) = value {
                    viewModel.gestureMapper.dragEnd(at: drag.location, in: size)
                }
            }
    }

    private func scrollGesture(size: CGSize) -> some Gesture {
        // Two-finger pan reported by SwiftUI as a drag with two touches on iPad/iOS 17.
        DragGesture(minimumDistance: 5)
            .onChanged { value in
                viewModel.gestureMapper.scroll(
                    translationDelta: CGSize(width: value.velocity.width / 60,
                                             height: value.velocity.height / 60))
            }
    }
}
