// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TimeBoxerMac",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .executable(name: "TimeBoxerMac", targets: ["TimeBoxerMac"]),
    ],
    targets: [
        .executableTarget(
            name: "TimeBoxerMac",
            path: "Sources/TimeBoxerMac"
        ),
        .testTarget(
            name: "TimeBoxerMacTests",
            dependencies: ["TimeBoxerMac"],
            path: "Tests/TimeBoxerMacTests"
        ),
    ]
)
