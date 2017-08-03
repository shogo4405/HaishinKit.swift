import PackageDescription

let package = Package(
    name: "HaishinKit",
    dependencies: [
        .Package(url: "https://github.com/DaveWoodCom/XCGLogger.git", majorVersion: 5)
    ]
)

