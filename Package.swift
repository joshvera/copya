// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "COPYA",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .executable(name: "COPYA", targets: ["COPYA"]),
    ],
    targets: [
        .executableTarget(
            name: "COPYA",
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
    ]
)
