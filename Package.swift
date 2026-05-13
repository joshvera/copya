// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "COPYA",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .executable(name: "COPYA", targets: ["COPYA"]),
        .library(name: "COPYACore", targets: ["COPYACore"]),
    ],
    targets: [
        .target(
            name: "COPYACore",
            path: "Sources/COPYACore"
        ),
        .executableTarget(
            name: "COPYA",
            dependencies: ["COPYACore"],
            path: "Sources/COPYA",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("CoreLocation"),
                .linkedFramework("CoreWLAN"),
                .linkedFramework("Network"),
                .linkedFramework("Security"),
                .linkedFramework("SwiftUI"),
            ]
        ),
        .testTarget(
            name: "COPYACoreTests",
            dependencies: ["COPYACore"],
            path: "tests/COPYACoreTests"
        ),
    ]
)
