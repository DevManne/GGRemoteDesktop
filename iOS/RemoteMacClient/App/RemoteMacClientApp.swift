import SwiftUI

/// Entry point for the iOS client application.
///
/// The client scans the host's pairing QR, connects over WebRTC, renders the remote
/// screen, and forwards touch/keyboard input as encrypted `ControlEvent`s. A single
/// `ClientViewModel` owns the services and is shared via the environment (MVVM).
@main
struct RemoteMacClientApp: App {
    @StateObject private var viewModel = ClientViewModel()

    var body: some Scene {
        WindowGroup {
            ClientRootView()
                .environmentObject(viewModel)
                .preferredColorScheme(nil) // follow system (dark mode supported)
        }
    }
}
