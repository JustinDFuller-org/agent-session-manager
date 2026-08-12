import XCTest

@testable import AgentSessionManager

final class ChildProcessOutputReaderTests: XCTestCase {
    override func setUp() {
        super.setUp()
        InvariantReporter.shared.resetForTesting()
        TracingService.shared.resetForTesting()
    }

    override func tearDown() {
        InvariantReporter.shared.resetForTesting()
        TracingService.shared.resetForTesting()
        super.tearDown()
    }

    func testReturnsDataWhenPipeClosesBeforeDeadline() {
        let pipe = Pipe()
        let payload = Data("hello".utf8)
        pipe.fileHandleForWriting.write(payload)
        try? pipe.fileHandleForWriting.close()

        let data = ChildProcessOutputReader.readToEndOfFile(
            pipe.fileHandleForReading, site: "test.closes-before-deadline", timeout: 1)

        XCTAssertEqual(data, payload)
    }

    /// Simulates a child that leaves a grandchild holding the pipe's write end open: the read
    /// end never sees EOF, so a raw `readDataToEndOfFile()` would block forever. The helper must
    /// still return within its timeout.
    func testReturnsEmptyDataWhenWriteEndStaysOpen() {
        let pipe = Pipe()
        // Deliberately never close pipe.fileHandleForWriting — held open for the test's duration,
        // standing in for a grandchild process that outlives the direct child.
        let start = Date()

        let data = ChildProcessOutputReader.readToEndOfFile(
            pipe.fileHandleForReading, site: "test.write-end-stays-open", timeout: 0.2)

        XCTAssertTrue(data.isEmpty)
        XCTAssertLessThan(Date().timeIntervalSince(start), 2, "must return near the timeout, not hang")
    }

    func testTimeoutRecordsInvariantViolation() {
        InvariantReporter.shared.enableTestCapture()
        let pipe = Pipe()

        _ = ChildProcessOutputReader.readToEndOfFile(
            pipe.fileHandleForReading, site: "test.invariant-site", timeout: 0.2)

        let violation = InvariantReporter.shared.violationsForTesting.first
        XCTAssertEqual(violation?.invariantID, "process.output_read.bounded")
        XCTAssertEqual(violation?.context["site"], "test.invariant-site")
    }
}
