// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "SwiftSunburstPrototype",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "SunburstCore",
            targets: ["SunburstCore"]
        ),
        .executable(
            name: "SunburstPreview",
            targets: ["SunburstPreview"]
        )
    ],
    targets: [
        .target(
            name: "SunburstCore"
        ),
        .executableTarget(
            name: "SunburstPreview",
            dependencies: ["SunburstCore"],
            resources: [
                .process("Resources")
            ]
        )
    ]
)
