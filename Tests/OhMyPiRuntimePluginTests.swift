import XCTest

@testable import AgentSessionManager

final class OhMyPiRuntimePluginTests: XCTestCase {
    func testPrepareUsesDistinctPrivateDirectoriesForSamePane() throws {
        let paneID = UUID()
        let first = try OhMyPiRuntimePlugin.prepare(paneID: paneID)
        let second = try OhMyPiRuntimePlugin.prepare(paneID: paneID)
        defer {
            OhMyPiRuntimePlugin.remove(directory: first)
            OhMyPiRuntimePlugin.remove(directory: second)
        }

        XCTAssertNotEqual(first, second)
        XCTAssertTrue(OhMyPiRuntimePlugin.isAppOwned(first))
        XCTAssertTrue(OhMyPiRuntimePlugin.isPrivateRuntimeDirectory(first, requiresMCP: false))
        XCTAssertTrue(FileManager.default.fileExists(atPath: first.appending(path: "main.mjs").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: first.appending(path: "package.json").path))
        XCTAssertFalse(
            FileManager.default.fileExists(atPath: first.appending(path: OhMyPiRuntimePlugin.statusFilename).path))
    }

    func testOwnershipRejectsPrefixesSiblingsAndTraversal() {
        let paneID = "11111111-1111-1111-1111-111111111111"
        let launchID = "22222222-2222-2222-2222-222222222222"
        let temporaryDirectory = FileManager.default.temporaryDirectory
        let owned = temporaryDirectory.appending(path: "agent-session-manager-omp-\(paneID)-\(launchID)")

        XCTAssertTrue(OhMyPiRuntimePlugin.isAppOwned(owned))
        XCTAssertFalse(
            OhMyPiRuntimePlugin.isAppOwned(
                temporaryDirectory.appending(path: "agent-session-manager-omp-\(paneID)-\(launchID)-extra")))
        XCTAssertFalse(
            OhMyPiRuntimePlugin.isAppOwned(
                temporaryDirectory.appending(path: "not-agent-session-manager-omp-\(paneID)-\(launchID)")))
        XCTAssertFalse(
            OhMyPiRuntimePlugin.isAppOwned(
                temporaryDirectory.appending(path: "nested/agent-session-manager-omp-\(paneID)-\(launchID)")))
    }
}
