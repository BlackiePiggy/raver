// swift-tools-version:6.1
import PackageDescription

let package = Package(
    name: "RaverEventAdminContract",
    platforms: [
        .iOS(.v17),
        .macOS(.v13),
    ],
    products: [
        .library(
            name: "RaverEventAdminContract",
            targets: ["RaverEventAdminContract"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-openapi-runtime", from: "1.7.0"),
    ],
    targets: [
        .target(
            name: "RaverEventAdminContract",
            dependencies: [
                .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime")
            ]
        )
    ]
)
