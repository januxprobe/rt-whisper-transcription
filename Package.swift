// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "RTWhisperCLI",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/argmaxinc/WhisperKit.git", from: "0.15.0"),
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0")
    ],
    targets: [
        .target(
            name: "RTWhisperLib",
            dependencies: [
                "WhisperKit"
            ],
            path: "Sources/RTWhisperLib"
        ),
        .executableTarget(
            name: "RTWhisperCLI",
            dependencies: [
                "RTWhisperLib",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ]
        ),
        .testTarget(
            name: "RTWhisperTests",
            dependencies: ["RTWhisperLib"]
        )
    ]
)
