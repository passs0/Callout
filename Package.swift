// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Callout",
    platforms: [
        .macOS(.v26)
    ],
    products: [
        .executable(name: "Callout", targets: ["Callout"])
    ],
    targets: [
        .executableTarget(
            name: "Callout",
            path: "Sources/Callout",
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
