// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "BabySmash",
    platforms: [.macOS(.v12)],
    targets: [
        .executableTarget(
            name: "BabySmash",
            path: "Sources/BabySmash"
        )
    ]
)
