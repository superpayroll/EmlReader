// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "EmlReader",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "EmlReader",
            path: "Sources/EmlReader"
        )
    ]
)
