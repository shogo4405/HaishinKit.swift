// swift-tools-version:5.1
// The swift-tools-version declares the minimum version of Swift required to build this package.
import PackageDescription

let package = Package(
    name: "HaishinKit",
    platforms: [
        .iOS(.v9),
        .tvOS("10.2"),
        .macOS(.v10_11)
    ],
    products: [
        .library(name: "HaishinKit", targets: ["HaishinKit"])
    ],
    dependencies: [
        .package(url: "https://github.com/shogo4405/Logboard.git", from: "2.2.2")
    ],
    targets: [
        .target(name: "SwiftPMSupport"),
        .target(name: "HaishinKit",
                dependencies: ["Logboard", "SwiftPMSupport"],
                path: "Sources",
                sources: [
                    "Codec",
                    "Extension",
                    "FLV",
                    "HTTP",
                    "ISO",
                    "Media",
                    "MP4",
                    "Net",
                    "PiP",
                    "RTMP",
                    "Util",
                    "Platforms",
                    "TS"
                ])
    ]
)
