import SwiftUI
import CoreImage.CIFilterBuiltins

/// Renders the pairing payload as a QR code plus the short auth string the user
/// verifies on both devices to defeat man-in-the-middle attacks.
struct PairingQRView: View {
    let payload: String
    let authString: String?

    private let context = CIContext()
    private let filter = CIFilter.qrCodeGenerator()

    var body: some View {
        VStack(spacing: 12) {
            Text("Scan to pair").font(.headline)
            if let image = qrImage() {
                Image(decorative: image, scale: 1)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 220, height: 220)
                    .padding(8)
                    .background(.white, in: RoundedRectangle(cornerRadius: 12))
            }
            if let authString {
                VStack(spacing: 2) {
                    Text("Verification code").font(.caption).foregroundStyle(.secondary)
                    Text(authString)
                        .font(.system(.title3, design: .monospaced)).bold()
                        .tracking(4)
                }
            }
        }
    }

    /// Generate a crisp QR `CGImage` from the payload string.
    private func qrImage() -> CGImage? {
        filter.message = Data(payload.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
        return context.createCGImage(scaled, from: scaled.extent)
    }
}
