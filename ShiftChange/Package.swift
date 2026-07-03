// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    // Package name must stay "ShiftChange": SwiftPM derives the resource
    // bundle name (ShiftChange_ShiftChange.bundle) from it, and both
    // Bundle.module and create-dmg.sh depend on that. A mismatch makes the
    // packaged app crash at launch (this shipped broken in v1.0.0–v1.1.2).
    name: "ShiftChange",
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
            name: "ShiftChange",
            dependencies: ["CBlueLightBridge"],
            path: "Sources/ShiftChange",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "ShiftChangeTests",
            dependencies: ["ShiftChange"],
            path: "Tests/ShiftChangeTests"
        ),
    ]
)
