// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.
import PackageDescription

let package = Package(
    name: "HaishinKit",
    platforms: [
        .iOS(.v11),
        .tvOS(.v11),
        .macOS(.v10_13),
        .macCatalyst(.v14)
    ],
    products: [
        .library(name: "HaishinKit", targets: ["HaishinKit"]),
        .library(name: "SRTHaishinKit", targets: ["SRTHaishinKit"])
    ],
    dependencies: [
        .package(url: "https://github.com/shogo4405/Logboard.git", from: "2.3.1")
    ],
    targets: [
        .binaryTarget(
            name: "libsrt",
            path: "Vendor/SRT/libsrt.xcframework"
        ),
        .target(name: "SwiftPMSupport"),
        .target(name: "HaishinKit",
                dependencies: ["Logboard", "SwiftPMSupport"],
                path: "Sources",
                exclude: [
                    "Platforms/iOS/Info.plist"
                ],
                sources: [
                    "Codec",
                    "Extension",
                    "FLV",
                    "HTTP",
                    "Media",
                    "MPEG",
                    "Net",
                    "RTMP",
                    "Util",
                    "Platforms"
                ]),
        .target(name: "SRTHaishinKit",
                dependencies: [
                    "libsrt",
                    "HaishinKit"
                ],
                path: "SRTHaishinKit"
        )
    ]
)
