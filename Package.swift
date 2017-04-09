import PackageDescription

let package = Package(
    name: "lf",
    dependencies: [
        .Package(url: "https://github.com/DaveWoodCom/XCGLogger.git", majorVersion: 5)
    ]
)

