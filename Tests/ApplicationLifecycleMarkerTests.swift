import Foundation
import XCTest

@testable import AgentSessionManager

final class ApplicationLifecycleMarkerTests: XCTestCase {
    private var supportDirectory: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        let subdirectory = "lifecycle-marker-test-\(UUID().uuidString)"
        PersistenceHelpers.overrideAppSupportSubdirectory = subdirectory
        supportDirectory = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0].appending(path: subdirectory)
    }

    override func tearDownWithError() throws {
        if let supportDirectory {
            try? FileManager.default.removeItem(at: supportDirectory)
        }
        PersistenceHelpers.overrideAppSupportSubdirectory = nil
        try super.tearDownWithError()
    }

    func testRunningMarkerDetectsPreviousUncleanExit() {
        let launchID = UUID()
        let firstLaunch = ApplicationLifecycleMarker.record(.running, launchID: launchID)
        let secondLaunch = ApplicationLifecycleMarker.record(.running, launchID: launchID)

        XCTAssertEqual(firstLaunch.previousExit, .unknown)
        XCTAssertEqual(firstLaunch.writeResult, .written)
        XCTAssertEqual(secondLaunch.previousExit, .unclean)
        XCTAssertEqual(secondLaunch.writeResult, .written)
    }

    func testCleanMarkerMakesNextLaunchClean() {
        let launchID = UUID()
        _ = ApplicationLifecycleMarker.record(.running, launchID: launchID)
        let shutdown = ApplicationLifecycleMarker.record(.clean, launchID: launchID)
        let nextLaunch = ApplicationLifecycleMarker.record(.running, launchID: UUID())

        XCTAssertEqual(shutdown.writeResult, .written)
        XCTAssertEqual(nextLaunch.previousExit, .clean)
        XCTAssertEqual(nextLaunch.writeResult, .written)
    }

    func testOlderInstanceCannotMarkNewerInstanceClean() {
        let olderLaunchID = UUID()
        let newerLaunchID = UUID()
        _ = ApplicationLifecycleMarker.record(.running, launchID: olderLaunchID)
        _ = ApplicationLifecycleMarker.record(.running, launchID: newerLaunchID)

        let olderShutdown = ApplicationLifecycleMarker.record(.clean, launchID: olderLaunchID)
        let launchAfterNewerCrash = ApplicationLifecycleMarker.record(.running, launchID: UUID())

        XCTAssertEqual(olderShutdown.writeResult, .ownershipMismatch)
        XCTAssertEqual(launchAfterNewerCrash.previousExit, .unclean)
    }

    func testUnsupportedSchemaIsUnknown() throws {
        try FileManager.default.createDirectory(at: supportDirectory, withIntermediateDirectories: true)
        let launchID = UUID()
        let unsupported = """
            {"schemaVersion":2,"state":"clean","launchID":"\(launchID.uuidString)","timestamp":0}
            """
        try Data(unsupported.utf8).write(to: supportDirectory.appending(path: "app-lifecycle.json"))

        let launch = ApplicationLifecycleMarker.record(.running, launchID: UUID())

        XCTAssertEqual(launch.previousExit, .unknown)
        XCTAssertEqual(launch.writeResult, .written)
    }

    func testDeathDuringTeardownIsDistinguishedFromDeathWhileRunning() {
        let launchID = UUID()
        _ = ApplicationLifecycleMarker.record(.running, launchID: launchID)
        _ = ApplicationLifecycleMarker.record(.terminating, launchID: launchID)
        let nextLaunch = ApplicationLifecycleMarker.record(.running, launchID: UUID())

        XCTAssertEqual(nextLaunch.previousExit, .uncleanDuringTeardown)
    }

    func testOlderInstanceCannotMarkNewerInstanceTerminating() {
        let olderLaunchID = UUID()
        let newerLaunchID = UUID()
        _ = ApplicationLifecycleMarker.record(.running, launchID: olderLaunchID)
        _ = ApplicationLifecycleMarker.record(.running, launchID: newerLaunchID)

        let olderTerminating = ApplicationLifecycleMarker.record(.terminating, launchID: olderLaunchID)

        XCTAssertEqual(olderTerminating.writeResult, .ownershipMismatch)
    }

    func testHeartbeatTracksPeakFootprintAcrossCalls() {
        let launchID = UUID()
        _ = ApplicationLifecycleMarker.record(.running, launchID: launchID, footprintBytes: 100)
        _ = ApplicationLifecycleMarker.record(.running, launchID: launchID, footprintBytes: 50)
        let thirdHeartbeat = ApplicationLifecycleMarker.record(.running, launchID: launchID, footprintBytes: 75)

        XCTAssertEqual(thirdHeartbeat.previousPeakFootprintBytes, 100)

        let nextLaunch = ApplicationLifecycleMarker.record(.running, launchID: UUID())
        XCTAssertEqual(nextLaunch.previousPeakFootprintBytes, 100)
    }

    func testHeartbeatTimestampSurfacesAtNextLaunch() throws {
        let launchID = UUID()
        _ = ApplicationLifecycleMarker.record(.running, launchID: launchID)
        _ = ApplicationLifecycleMarker.record(.running, launchID: launchID)

        let nextLaunch = ApplicationLifecycleMarker.record(.running, launchID: UUID())

        let heartbeatAt = try XCTUnwrap(nextLaunch.previousHeartbeatAt)
        XCTAssertEqual(heartbeatAt.timeIntervalSinceNow, 0, accuracy: 5)
    }

    func testCurrentFootprintBytesReadsRunningProcess() {
        XCTAssertNotNil(ApplicationLifecycleMarker.currentFootprintBytes())
    }
}
