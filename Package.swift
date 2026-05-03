// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AgentSessionManager",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/migueldeicaza/SwiftTerm.git", from: "1.13.0"),
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
