// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "MaraAI",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "MaraAI",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "MaraAITests",
            dependencies: ["MaraAI"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
