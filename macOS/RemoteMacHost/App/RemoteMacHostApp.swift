import SwiftUI

/// Entry point for the macOS host application.
///
/// The host captures the Mac screen, streams it over WebRTC, and injects the remote
/// input it receives. A single `HostViewModel` owns the long-lived services and is
/// shared with the UI via the environment (MVVM).
@main
struct RemoteMacHostApp: App {
    @StateObject private var viewModel = HostViewModel()

    var body: some Scene {
        WindowGroup("RemoteMac Host") {
            HostView()
                .environmentObject(viewModel)
                .frame(minWidth: 460, minHeight: 560)
        }
        .windowResizability(.contentSize)
    }
}
