// swift-tools-version: 5.8
import PackageDescription

let package = Package(
    name: "LettersCore",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [.library(name: "LettersCore", targets: ["LettersCore"])],
    targets: [
        .target(name: "LettersCore"),
        .testTarget(name: "LettersCoreTests", dependencies: ["LettersCore"])
    ]
)
