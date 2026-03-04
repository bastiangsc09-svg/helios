import SwiftUI
import AVFoundation

struct QRScannerView: View {
    let onScan: ([String: Any]) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var scanError: String?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                QRCameraView { code in
                    parseAndDeliver(code)
                }

                // Viewfinder overlay
                VStack {
                    Spacer()

                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(.white.opacity(0.5), lineWidth: 2)
                        .frame(width: 250, height: 250)
                        .overlay {
                            // Corner accents
                            GeometryReader { geo in
                                let w = geo.size.width
                                let h = geo.size.height
                                let corner: CGFloat = 30
                                let lw: CGFloat = 3

                                Path { p in
                                    // Top-left
                                    p.move(to: CGPoint(x: 0, y: corner))
                                    p.addLine(to: CGPoint(x: 0, y: 0))
                                    p.addLine(to: CGPoint(x: corner, y: 0))
                                    // Top-right
                                    p.move(to: CGPoint(x: w - corner, y: 0))
                                    p.addLine(to: CGPoint(x: w, y: 0))
                                    p.addLine(to: CGPoint(x: w, y: corner))
                                    // Bottom-right
                                    p.move(to: CGPoint(x: w, y: h - corner))
                                    p.addLine(to: CGPoint(x: w, y: h))
                                    p.addLine(to: CGPoint(x: w - corner, y: h))
                                    // Bottom-left
                                    p.move(to: CGPoint(x: corner, y: h))
                                    p.addLine(to: CGPoint(x: 0, y: h))
                                    p.addLine(to: CGPoint(x: 0, y: h - corner))
                                }
                                .stroke(Theme.sessionOrbit, lineWidth: lw)
                            }
                        }

                    Spacer()

                    VStack(spacing: 8) {
                        Text("Point camera at Helios QR code")
                            .font(.system(size: 15))
                            .foregroundStyle(.white.opacity(0.8))

                        if let error = scanError {
                            Text(error)
                                .font(.system(size: 13))
                                .foregroundStyle(Theme.tierCritical)
                        }
                    }
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Scan QR")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.white)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func parseAndDeliver(_ code: String) {
        guard let data = code.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              json["sessionKey"] is String,
              json["organizationID"] is String else {
            scanError = "Invalid QR code — not a Helios payload"
            return
        }
        onScan(json)
        dismiss()
    }
}

// MARK: - AVFoundation Camera

struct QRCameraView: UIViewControllerRepresentable {
    let onCode: (String) -> Void

    func makeUIViewController(context: Context) -> QRCameraController {
        let vc = QRCameraController()
        vc.onCode = onCode
        return vc
    }

    func updateUIViewController(_ uiViewController: QRCameraController, context: Context) {}
}

final class QRCameraController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onCode: ((String) -> Void)?
    private let session = AVCaptureSession()
    private var hasDelivered = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device) else { return }

        if session.canAddInput(input) { session.addInput(input) }

        let output = AVCaptureMetadataOutput()
        if session.canAddOutput(output) {
            session.addOutput(output)
            output.setMetadataObjectsDelegate(self, queue: .main)
            output.metadataObjectTypes = [.qr]
        }

        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        preview.frame = view.bounds
        view.layer.addSublayer(preview)

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.startRunning()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if let preview = view.layer.sublayers?.first as? AVCaptureVideoPreviewLayer {
            preview.frame = view.bounds
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        session.stopRunning()
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard !hasDelivered,
              let obj = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let code = obj.stringValue else { return }
        hasDelivered = true
        onCode?(code)
    }
}
