// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SRTHaishinKit",
    platforms: [
        .iOS(.v13),
        .tvOS(.v13),
        .visionOS(.v1),
        .macOS(.v13),
        .macCatalyst(.v14)
    ],
    products: [
        .library(name: "SRTHaishinKit", targets: ["SRTHaishinKit"])
    ],
    dependencies: [
        .package(path: "../HaishinKit")
    ],
    targets: [
        .binaryTarget(
            name: "libsrt",
            path: "Vendor/SRT/libsrt.xcframework"
        ),
        .target(name: "SRTHaishinKit",
                dependencies: ["HaishinKit", "libsrt"],
                path: "Sources"
        ),
        .testTarget(
            name: "SRTHaishinKitTests", dependencies: ["SRTHaishinKit"]
        )
    ],
    swiftLanguageModes: [.version("5")]
)
