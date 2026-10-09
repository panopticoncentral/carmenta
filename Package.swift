// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Carmenta",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "Carmenta", targets: ["Carmenta"])],
    targets: [
        .target(name: "CarmentaCore"),
        .executableTarget(name: "Carmenta", dependencies: ["CarmentaCore"]),
        .testTarget(name: "CarmentaCoreTests", dependencies: ["CarmentaCore"])
    ],
    swiftLanguageModes: [.v5]
)
