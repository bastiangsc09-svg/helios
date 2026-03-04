import SwiftUI
import CoreImage.CIFilterBuiltins

struct QRGeneratorView: View {
    let state: UsageState

    var body: some View {
        VStack(spacing: 12) {
            if state.hasSessionConfig {
                if let qrImage = generateQR() {
                    Image(nsImage: qrImage)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 180, height: 180)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                Text("Scan this from Helios iOS")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            } else {
                Text("Configure session key first")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 8)
    }

    private func generateQR() -> NSImage? {
        let payload: [String: Any] = [
            "sessionKey": state.sessionKey,
            "organizationID": state.organizationID,
            "version": 1
        ]
        guard let jsonData = try? JSONSerialization.data(withJSONObject: payload),
              let jsonString = String(data: jsonData, encoding: .utf8) else { return nil }

        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(jsonString.utf8)
        filter.correctionLevel = "M"

        guard let ciImage = filter.outputImage else { return nil }

        // Scale up for sharpness
        let scale = 10.0
        let transformed = ciImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let rep = NSCIImageRep(ciImage: transformed)
        let nsImage = NSImage(size: rep.size)
        nsImage.addRepresentation(rep)
        return nsImage
    }
}
