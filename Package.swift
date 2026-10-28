// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Purr",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "Purr", path: "Sources/Purr")
    ]
)
