import Foundation
import Vision

// Check the actual native screenshot rather than only the QR encoder's input.
let url = URL(fileURLWithPath: CommandLine.arguments[1])
let request = VNDetectBarcodesRequest()
request.symbologies = [.qr]
try VNImageRequestHandler(url: url, options: [:]).perform([request])
let payloads = (request.results ?? []).compactMap(\.payloadStringValue)
let pattern = #"^letters-preview://invite\?code=DEMO-LBOX-([ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{8}-){3}[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{8}$"#
guard payloads.count == 1, payloads[0].range(of: pattern, options: .regularExpression) != nil else {
    fatalError("Letterbox screenshot must contain one readable matching preview QR code")
}
print("Letterbox screenshot QR decoded and validated; token omitted from logs.")
