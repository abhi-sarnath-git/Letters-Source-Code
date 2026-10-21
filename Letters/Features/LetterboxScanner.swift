import SwiftUI
import AVFoundation
import UIKit

struct LetterboxScanner: UIViewControllerRepresentable {
    let scanned: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    func makeUIViewController(context: Context) -> ScannerController {
        let controller = ScannerController()
        controller.scanned = scanned
        controller.closed = { dismiss() }
        return controller
    }
    func updateUIViewController(_ controller: ScannerController, context: Context) {}
    static func dismantleUIViewController(_ controller: ScannerController, coordinator: ()) { controller.stop() }
}

final class ScannerController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var scanned: ((String) -> Void)?
    var closed: (() -> Void)?
    private let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "letters.qr-camera")
    private let message = UILabel()
    private var layer: AVCaptureVideoPreviewLayer?
    private var consumed = false
    private var visible = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        message.text = "Point the camera at a Letterbox QR code. Nothing is uploaded."
        message.textColor = .white; message.numberOfLines = 0; message.textAlignment = .center
        message.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(message)
        let close = UIButton(type: .system)
        close.setTitle("Close scanner", for: .normal)
        close.addTarget(self, action: #selector(closeScanner), for: .touchUpInside)
        close.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(close)
        NSLayoutConstraint.activate([
            message.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            message.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            message.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -70),
            close.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            close.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            close.heightAnchor.constraint(greaterThanOrEqualToConstant: 44)
        ])
        NotificationCenter.default.addObserver(self, selector: #selector(backgrounded), name: UIApplication.didEnterBackgroundNotification, object: nil)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        visible = true
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: configure()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    guard let self, self.visible else { return }
                    if granted { self.configure() } else { self.unavailable() }
                }
            }
        default: unavailable()
        }
    }

    override func viewDidDisappear(_ animated: Bool) { super.viewDidDisappear(animated); visible = false; stop() }
    override func viewDidLayoutSubviews() { super.viewDidLayoutSubviews(); layer?.frame = view.bounds }
    deinit { NotificationCenter.default.removeObserver(self) }
    @objc private func closeScanner() { stop(); closed?() }
    @objc private func backgrounded() { stop(); closed?() }
    func stop() { queue.async { [session] in if session.isRunning { session.stopRunning() } } }
    private func unavailable() {
        message.text = "Camera unavailable or permission denied. Close this scanner to enter a code or choose a QR image. You can allow camera access in iPhone Settings."
    }

    private func configure() {
        guard session.inputs.isEmpty else { return }
        guard let camera = AVCaptureDevice.default(for: .video), let input = try? AVCaptureDeviceInput(device: camera),
              session.canAddInput(input) else { unavailable(); return }
        let output = AVCaptureMetadataOutput()
        session.beginConfiguration()
        session.addInput(input)
        guard session.canAddOutput(output) else { session.commitConfiguration(); unavailable(); return }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        guard output.availableMetadataObjectTypes.contains(.qr) else { session.commitConfiguration(); unavailable(); return }
        output.metadataObjectTypes = [.qr]
        session.commitConfiguration()
        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        view.layer.insertSublayer(preview, at: 0)
        layer = preview; preview.frame = view.bounds
        queue.async { [session] in session.startRunning() }
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput objects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard visible, !consumed, let payload = (objects.first as? AVMetadataMachineReadableCodeObject)?.stringValue else { return }
        consumed = true; stop(); scanned?(payload)
    }
}
