// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AgentSessionManager",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/JustinDFuller/SwiftTerm.git", revision: "2714960a6ad76ae1f50a63f94aefe0e68d39df89"),
    ],
    targets: [
        .executableTarget(
            name: "AgentSessionManager",
            dependencies: [
                .product(name: "SwiftTerm", package: "SwiftTerm")
            ],
            path: "Sources/AgentSessionManager"
        ),
        .testTarget(
            name: "AgentSessionManagerTests",
            dependencies: ["AgentSessionManager"],
            path: "Tests"
        )
    ]
)
