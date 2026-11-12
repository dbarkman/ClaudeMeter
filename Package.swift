// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ClaudeMeter",
    platforms: [.macOS(.v14)],
    targets: [
        .target(
            name: "ClaudeMeterCore",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .executableTarget(
            name: "ClaudeMeter",
            dependencies: ["ClaudeMeterCore"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "ClaudeMeterCoreTests",
            dependencies: ["ClaudeMeterCore"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
