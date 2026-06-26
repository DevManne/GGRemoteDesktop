import SwiftUI

/// Top-level client navigation: shows the connect/scan flow when disconnected and the
/// live remote-control surface when connected. Adapts to dark mode via semantic colors.
struct ClientRootView: View {
    @EnvironmentObject private var viewModel: ClientViewModel

    var body: some View {
        Group {
            switch viewModel.state {
            case .connected, .reconnecting:
                RemoteControlView()
            case .scanning:
                ScanView()
            default:
                ConnectView()
            }
        }
        .animation(.default, value: viewModel.state)
    }
}

/// Landing screen with the call to action to begin pairing.
struct ConnectView: View {
    @EnvironmentObject private var viewModel: ClientViewModel

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "macbook.and.iphone")
                .font(.system(size: 56))
                .foregroundStyle(.tint)
            Text("RemoteMac").font(.largeTitle).bold()
            Text("Control your Mac from here. Scan the pairing code shown on your Mac to connect securely.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            if case let .failed(message) = viewModel.state {
                Text(message).font(.footnote).foregroundStyle(.red)
                    .multilineTextAlignment(.center).padding(.horizontal)
            }
            Spacer()
            Button {
                viewModel.beginScanning()
            } label: {
                Label("Scan Pairing Code", systemImage: "qrcode.viewfinder")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }
}

/// Camera scanning screen; passes the decoded payload to the view model.
struct ScanView: View {
    @EnvironmentObject private var viewModel: ClientViewModel

    var body: some View {
        ZStack {
            QRScannerView { value in
                Task { await viewModel.handleScannedPayload(value) }
            }
            .ignoresSafeArea()

            VStack {
                Spacer()
                Text("Point the camera at the code on your Mac")
                    .padding()
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.bottom, 40)
            }
        }
    }
}
