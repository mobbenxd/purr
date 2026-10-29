// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Purr",
    platforms: [.macOS(.v14)],
    targets: [
        // Everything that can be tested without a UI: parsing Mole output,
        // versions, alerts and the process runner.
        .target(name: "PurrCore", path: "Sources/PurrCore"),
        .executableTarget(name: "Purr", dependencies: ["PurrCore"], path: "Sources/Purr"),
        .testTarget(
            name: "PurrCoreTests",
            dependencies: ["PurrCore"],
            path: "Tests/PurrCoreTests",
            resources: [.copy("Fixtures")]
        ),
    ]
)
