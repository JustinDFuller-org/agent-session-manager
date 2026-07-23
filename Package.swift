// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "AgentSessionManager",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/migueldeicaza/SwiftTerm.git", from: "1.13.0"),
        .package(url: "https://github.com/open-telemetry/opentelemetry-swift", from: "1.9.0"),
        .package(url: "https://github.com/modelcontextprotocol/swift-sdk.git", exact: "0.12.1"),
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.65.0"),
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
                .product(name: "MCP", package: "swift-sdk"),
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "NIOPosix", package: "swift-nio"),
                .product(name: "NIOHTTP1", package: "swift-nio"),
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
    ],
    swiftLanguageModes: [.v6]
)
