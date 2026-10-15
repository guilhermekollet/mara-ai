// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "MaraAI",
    // The interface is written in Brazilian Portuguese and translated in Sources/MaraAI/Resources.
    defaultLocalization: "pt-BR",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "MaraAI",
            resources: [.process("Resources")],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "MaraAITests",
            dependencies: ["MaraAI"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
