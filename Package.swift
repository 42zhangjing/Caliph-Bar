// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CaliphBar",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "CaliphBar", targets: ["CaliphBar"]),
    ],
    targets: [
        .target(
            name: "CaliphBarCore",
            path: "Sources/CaliphBarCore"
        ),
        .executableTarget(
            name: "CaliphBar",
            dependencies: ["CaliphBarCore"],
            path: "Sources/CaliphBar"
        ),
        .testTarget(
            name: "CaliphBarCoreTests",
            dependencies: ["CaliphBarCore"],
            path: "Tests/CaliphBarCoreTests"
        ),
    ]
)
