// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "WebMediaDownloader",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "WebMediaDownloader", targets: ["WebMediaDownloader"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "WebMediaDownloader",
            dependencies: [],
            path: "Sources",
            resources: [
                .process("app_icon.png"),
                .process("Credits.rtf")
            ]
        )
    ]
)
