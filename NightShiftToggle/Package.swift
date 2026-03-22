// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "NightShiftToggle",
    platforms: [.macOS(.v13)],
    targets: [
        .target(
            name: "CBlueLightBridge",
            path: "Sources/CBlueLightBridge",
            publicHeadersPath: "include",
            linkerSettings: [
                .linkedFramework("Foundation")
            ]
        ),
        .executableTarget(
            name: "NightShiftToggle",
            dependencies: ["CBlueLightBridge"],
            path: "Sources/NightShiftToggle",
            resources: [
                .process("Resources")
            ]
        ),
    ]
)
