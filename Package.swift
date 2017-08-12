import PackageDescription

let package = Package(
    name: "HaishinKit",
    dependencies: [
        .Package(url: "https://github.com/shogo4405/Logboard.git", majorVersion: 1)
    ]
)

