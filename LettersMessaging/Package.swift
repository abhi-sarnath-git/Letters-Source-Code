// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "LettersMessaging",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [.library(name: "LettersMessaging", targets: ["LettersMessaging"])],
    dependencies: [
        .package(url: "https://github.com/matrix-org/matrix-rust-components-swift", exact: "26.10.02")
    ],
    targets: [
        .target(name: "LettersMessaging", dependencies: [
            .product(name: "MatrixRustSDK", package: "matrix-rust-components-swift")
        ]),
        .testTarget(name: "LettersMessagingTests", dependencies: ["LettersMessaging"])
    ]
)
