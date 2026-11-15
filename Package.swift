// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "GlassSelect",
    platforms: [
        .macOS(.v26)
    ],
    products: [
        .executable(name: "GlassSelect", targets: ["GlassSelect"])
    ],
    targets: [
        .executableTarget(
            name: "GlassSelect",
            path: "Sources/GlassSelect",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("NaturalLanguage"),
                .linkedFramework("CoreServices"),
                .linkedFramework("Carbon"),
                .linkedFramework("Translation")
            ]
        )
    ]
)
