// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AgentSessionManager",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/JustinDFuller/SwiftTerm.git", revision: "2714960a6ad76ae1f50a63f94aefe0e68d39df89"),
        .package(url: "https://github.com/open-telemetry/opentelemetry-swift", from: "1.9.0"),
    ],
    targets: [
        .executableTarget(
            name: "AgentSessionManager",
            dependencies: [
                .product(name: "SwiftTerm", package: "SwiftTerm"),
                .product(name: "OpenTelemetryApi", package: "opentelemetry-swift"),
                .product(name: "OpenTelemetrySdk", package: "opentelemetry-swift"),
                .product(name: "StdoutExporter", package: "opentelemetry-swift"),
            ],
            path: "Sources/AgentSessionManager",
            linkerSettings: [.linkedLibrary("sqlite3")]
        ),
        .testTarget(
            name: "AgentSessionManagerTests",
            dependencies: ["AgentSessionManager"],
            path: "Tests"
        )
    ]
)
