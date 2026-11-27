// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Selection",
    platforms: [
        .macOS(.v26)
    ],
    products: [
        .executable(name: "Selection", targets: ["Selection"])
    ],
    targets: [
        .executableTarget(
            name: "Selection",
            path: "Sources/Selection",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI"),
                .linkedFramework("NaturalLanguage"),
                .linkedFramework("CoreServices"),
                .linkedFramework("Translation")
            ]
        )
    ]
)
