// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "HaishinKit",
    platforms: [
        .iOS(.v13),
        .tvOS(.v13),
        .visionOS(.v1),
        .macOS(.v10_15),
        .macCatalyst(.v14)
    ],
    products: [
        .library(name: "HaishinKit", targets: ["HaishinKit"])
    ],
    dependencies: [
        .package(url: "https://github.com/shogo4405/Logboard.git", "2.5.0"..<"2.6.0")
    ],
    targets: [
        .target(
            name: "HaishinKit",
            dependencies: ["Logboard"],
            path: "Sources",
            sources: [
                "Codec",
                "Extension",
                "HKStream",
                "ISO",
                "Mixer",
                "Network",
                "RTMP",
                "Screen",
                "Util",
                "View"
            ]),
        .testTarget(
            name: "HaishinKitTests", dependencies: ["HaishinKit"],
            resources: [
                .process("TestData")
            ]
        )
    ],
    swiftLanguageModes: [.version("5"), .version("6")]
)
