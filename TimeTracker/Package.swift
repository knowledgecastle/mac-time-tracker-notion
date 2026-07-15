// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TimeTracker",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "TimeTracker",
            path: "TimeTracker"
        )
    ]
)
