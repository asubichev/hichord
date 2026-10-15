// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "rSplex",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "rSplexCore"),
        .executableTarget(name: "rSplex", dependencies: ["rSplexCore"]),
        .testTarget(name: "rSplexCoreTests", dependencies: ["rSplexCore"]),
    ]
)
