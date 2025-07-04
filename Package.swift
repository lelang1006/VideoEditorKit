// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "VideoEditorKit",
    platforms: [
        .iOS(.v14)
    ],
    products: [
        .library(
            name: "VideoEditorKit",
            targets: ["VideoEditorKit"]),
    ],
    dependencies: [
        .package(url: "https://github.com/PureLayout/PureLayout", .upToNextMajor(from: "3.1.6"))
    ],
    targets: [
        .target(
            name: "VideoEditorKit",
            dependencies: [
                "PureLayout"
            ],
            resources: [.process("Resources")]),
        .testTarget(
            name: "VideoEditorKitTests",
            dependencies: ["VideoEditorKit"])
    ]
)
