import SwiftUI
import SharedKit

/// Primary host screen: start/stop hosting, show the pairing QR + auth string, and
/// surface connection status and latency. Follows the Apple HIG with adaptive layout
/// and full dark-mode support (system materials + semantic colors).
struct HostView: View {
    @EnvironmentObject private var viewModel: HostViewModel

    var body: some View {
        VStack(spacing: 20) {
            header
            statusCard
            if let payload = viewModel.pairingQRPayload {
                PairingQRView(payload: payload, authString: viewModel.authString)
            }
            Spacer()
            controls
        }
        .padding(24)
        .background(.background)
    }

    private var header: some View {
        VStack(spacing: 4) {
            Image(systemName: "display")
                .font(.system(size: 34, weight: .regular))
                .foregroundStyle(.tint)
            Text("RemoteMac Host").font(.title2).bold()
            Text("Stream and control this Mac from your iPhone or iPad")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var statusCard: some View {
        HStack(spacing: 12) {
            Circle().fill(statusColor).frame(width: 10, height: 10)
            Text(statusText).font(.headline)
            Spacer()
            if let latency = viewModel.latencyMillis {
                Label("\(latency) ms", systemImage: "bolt.horizontal")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
    }

    private var controls: some View {
        HStack {
            Picker("Codec", selection: $viewModel.encoder) {
                ForEach(VideoEncoder.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 180)

            Spacer()

            if case .idle = viewModel.state {
                Button("Start Hosting") { Task { await viewModel.startHosting() } }
                    .buttonStyle(.borderedProminent)
            } else {
                Button("Stop", role: .destructive) { viewModel.stopHosting() }
                    .buttonStyle(.bordered)
            }
        }
    }

    private var statusText: String {
        switch viewModel.state {
        case .idle: return "Idle"
        case .advertising: return "Waiting for device…"
        case .connecting: return "Connecting…"
        case .connected: return "Connected"
        case .reconnecting: return "Reconnecting…"
        case .failed(let message): return "Error: \(message)"
        }
    }

    private var statusColor: Color {
        switch viewModel.state {
        case .connected: return .green
        case .advertising, .connecting, .reconnecting: return .orange
        case .failed: return .red
        case .idle: return .secondary
        }
    }
}
