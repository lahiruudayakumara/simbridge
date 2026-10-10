// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SimBridge",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "SimBridge", targets: ["SimBridgeApp"]),
        .executable(name: "simbridge-diagnose", targets: ["SimBridgeDiagnostics"]),
        .library(name: "SimBridgeCore", targets: ["SimBridgeCore"]),
        .library(name: "SimBridgeHardware", targets: ["SimBridgeHardware"]),
    ],
    targets: [
        .target(name: "SimBridgeCore"),
        .target(
            name: "SimBridgeHardware",
            dependencies: ["SimBridgeCore"],
            linkerSettings: [
                .linkedFramework("AVFoundation"),
                .linkedFramework("CoreBluetooth"),
            ]
        ),
        .executableTarget(
            name: "SimBridgeApp",
            dependencies: ["SimBridgeCore", "SimBridgeHardware"],
            linkerSettings: [.linkedFramework("AppKit"), .linkedFramework("SwiftUI")]
        ),
        .executableTarget(name: "SimBridgeDiagnostics", dependencies: ["SimBridgeCore"]),
        .testTarget(name: "SimBridgeCoreTests", dependencies: ["SimBridgeCore"]),
    ]
)
