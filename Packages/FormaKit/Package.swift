// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FormaKit",
    defaultLocalization: "tr",
    platforms: [
        .iOS(.v17),
        .watchOS(.v10),
        .macOS(.v14)
    ],
    products: [
        .library(name: "FormaKit", targets: ["FormaKit"])
    ],
    targets: [
        .target(
            name: "FormaKit",
            path: "Sources/FormaKit"
        ),
        .testTarget(
            name: "FormaKitTests",
            dependencies: ["FormaKit"],
            path: "Tests/FormaKitTests"
        )
    ]
)
