// swift-tools-version:6.0

import PackageDescription

let package = Package(
    name: "StuffMarkdown",
    platforms: [
        .macOS(.v13),
        .iOS(.v16),
        .watchOS(.v9),
        .tvOS(.v16),
        .visionOS(.v1)
    ],
    products: [
        .library(name: "StuffMarkdown", targets: ["StuffMarkdown"])
    ],
    targets: [
        .target(name: "StuffMarkdown"),
        .testTarget(
            name: "StuffMarkdownTests",
            dependencies: ["StuffMarkdown"]
        )
    ]
)
