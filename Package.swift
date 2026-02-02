// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "RoonKit",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .library(
            name: "RoonKit",
            targets: ["RoonKit"]
        ),
    ],
    targets: [
        .target(
            name: "RoonKit",
            path: "Sources/RoonKit"
        ),
        .testTarget(
            name: "RoonKitTests",
            dependencies: ["RoonKit"],
            path: "Tests/RoonKitTests"
        ),
    ]
)
