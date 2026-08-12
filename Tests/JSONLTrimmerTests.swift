import XCTest

@testable import AgentSessionManager

final class JSONLTrimmerTests: XCTestCase {
    private var testDir: URL!

    override func setUp() {
        super.setUp()
        testDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("jsonl-trimmer-test-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: testDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: testDir)
        super.tearDown()
    }

    private func write(_ contents: String, to url: URL) throws {
        try Data(contents.utf8).write(to: url)
    }

    func testFileAtCapIsNotRotated() throws {
        let file = testDir.appendingPathComponent("at-cap.jsonl")
        let contents = String(repeating: "x", count: 100)
        try write(contents, to: file)

        try JSONLTrimmer.trimIfNeeded(at: file, maxBytes: contents.utf8.count)

        XCTAssertFalse(FileManager.default.fileExists(atPath: JSONLTrimmer.rotatedURL(for: file).path))
        XCTAssertEqual(try String(contentsOf: file, encoding: .utf8), contents)
    }

    func testFileOverCapIsRotated() throws {
        let file = testDir.appendingPathComponent("over-cap.jsonl")
        let contents = String(repeating: "x", count: 200)
        try write(contents, to: file)

        try JSONLTrimmer.trimIfNeeded(at: file, maxBytes: 100)

        let rotated = JSONLTrimmer.rotatedURL(for: file)
        XCTAssertTrue(FileManager.default.fileExists(atPath: rotated.path))
        XCTAssertEqual(try String(contentsOf: rotated, encoding: .utf8), contents)
    }

    func testRotatedFileIsNamedWithSingleGenerationSuffix() {
        let file = URL(filePath: "/tmp/traces/_global/global.jsonl")
        XCTAssertEqual(
            JSONLTrimmer.rotatedURL(for: file).path,
            "/tmp/traces/_global/global.1.jsonl")
    }

    func testMetadataIsPreservedInFreshFileAfterRotation() throws {
        let file = testDir.appendingPathComponent("with-metadata.jsonl")
        let metadataLine = "{\"_type\":\"metadata\",\"schemaVersion\":1}"
        try write(metadataLine + "\n" + String(repeating: "x", count: 200), to: file)

        try JSONLTrimmer.trimIfNeeded(at: file, maxBytes: 100, preserveMetadata: true)

        XCTAssertTrue(FileManager.default.fileExists(atPath: JSONLTrimmer.rotatedURL(for: file).path))
        XCTAssertEqual(try String(contentsOf: file, encoding: .utf8), metadataLine + "\n")
    }

    func testMetadataIsNotPreservedWhenNotRequested() throws {
        let file = testDir.appendingPathComponent("without-preserve.jsonl")
        let metadataLine = "{\"_type\":\"metadata\",\"schemaVersion\":1}"
        try write(metadataLine + "\n" + String(repeating: "x", count: 200), to: file)

        try JSONLTrimmer.trimIfNeeded(at: file, maxBytes: 100)

        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: JSONLTrimmer.rotatedURL(for: file).path))
    }

    func testSecondRotationReplacesFirstGeneration() throws {
        let file = testDir.appendingPathComponent("double-rotate.jsonl")
        try write(String(repeating: "a", count: 200), to: file)
        try JSONLTrimmer.trimIfNeeded(at: file, maxBytes: 100)

        try write(String(repeating: "b", count: 200), to: file)
        try JSONLTrimmer.trimIfNeeded(at: file, maxBytes: 100)

        let rotated = JSONLTrimmer.rotatedURL(for: file)
        XCTAssertEqual(try String(contentsOf: rotated, encoding: .utf8), String(repeating: "b", count: 200))
    }

    func testUnderCapFileIsUntouched() throws {
        let file = testDir.appendingPathComponent("small.jsonl")
        try write("short", to: file)

        try JSONLTrimmer.trimIfNeeded(at: file, maxBytes: 10_000)

        XCTAssertFalse(FileManager.default.fileExists(atPath: JSONLTrimmer.rotatedURL(for: file).path))
        XCTAssertEqual(try String(contentsOf: file, encoding: .utf8), "short")
    }
}
