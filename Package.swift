// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "HiChord",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "HiChordCore"),
        .executableTarget(name: "HiChord", dependencies: ["HiChordCore"]),
        .testTarget(name: "HiChordCoreTests", dependencies: ["HiChordCore"]),
    ]
)
