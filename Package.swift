// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AgentSessionManager",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/migueldeicaza/SwiftTerm.git", from: "1.13.0"),
        .package(url: "https://github.com/open-telemetry/opentelemetry-swift", from: "1.9.0"),
    ],
    targets: [
        .executableTarget(
            name: "AgentSessionManager",
            dependencies: [
                .product(name: "SwiftTerm", package: "SwiftTerm"),
                .product(name: "OpenTelemetryApi", package: "opentelemetry-swift"),
                .product(name: "OpenTelemetrySdk", package: "opentelemetry-swift"),
                .product(name: "SignPostIntegration", package: "opentelemetry-swift"),
                .product(name: "ResourceExtension", package: "opentelemetry-swift"),
            ],
            path: "Sources/AgentSessionManager",
            linkerSettings: [
                .linkedLibrary("sqlite3"),
                .linkedFramework("Network"),
            ]
        ),
        .testTarget(
            name: "AgentSessionManagerTests",
            dependencies: ["AgentSessionManager"],
            path: "Tests"
        )
    ]
)
