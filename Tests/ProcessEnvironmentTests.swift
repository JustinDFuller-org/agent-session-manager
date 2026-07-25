import XCTest

@testable import AgentSessionManager

final class ProcessEnvironmentTests: XCTestCase {
    // MARK: - Helpers

    private func envDict(from env: [String]) -> [String: String] {
        var dict: [String: String] = [:]
        for entry in env {
            guard let separator = entry.firstIndex(of: "=") else { continue }
            let key = String(entry[..<separator])
            let value = String(entry[entry.index(after: separator)...])
            dict[key] = value
        }
        return dict
    }

    /// Creates a temporary directory with an `etc/paths` file and optional `etc/paths.d` files.
    private func makeEtcDirectory(paths: String, pathDEntries: [String: String] = [:]) throws -> String {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .path
        let etc = (root as NSString).appendingPathComponent("etc")
        let pathsD = (etc as NSString).appendingPathComponent("paths.d")
        try FileManager.default.createDirectory(atPath: pathsD, withIntermediateDirectories: true)
        try paths.write(toFile: (etc as NSString).appendingPathComponent("paths"), atomically: true, encoding: .utf8)
        for (name, content) in pathDEntries {
            try content.write(
                toFile: (pathsD as NSString).appendingPathComponent(name),
                atomically: true,
                encoding: .utf8)
        }
        return root
    }

    // MARK: - sanitize

    func testSanitizeAddsMissingTERM() {
        let env = ProcessEnvironment.sanitize([])
        let dict = envDict(from: env)
        XCTAssertEqual(dict["TERM"], "xterm-256color")
    }

    func testSanitizeAddsMissingCOLORTERM() {
        let env = ProcessEnvironment.sanitize([])
        let dict = envDict(from: env)
        XCTAssertEqual(dict["COLORTERM"], "truecolor")
    }

    func testSanitizeAddsMissingLANG() {
        let env = ProcessEnvironment.sanitize([])
        let dict = envDict(from: env)
        XCTAssertEqual(dict["LANG"], "en_US.UTF-8")
    }

    func testSanitizePreservesExistingTERM() {
        let env = ProcessEnvironment.sanitize(["TERM=dumb"])
        let dict = envDict(from: env)
        XCTAssertEqual(dict["TERM"], "dumb")
    }

    func testSanitizePreservesNO_COLOR() {
        let env = ProcessEnvironment.sanitize(["NO_COLOR=1"])
        let dict = envDict(from: env)
        XCTAssertEqual(dict["NO_COLOR"], "1")
        XCTAssertEqual(dict["TERM"], "xterm-256color")
        XCTAssertEqual(dict["COLORTERM"], "truecolor")
    }

    func testSanitizeAddsDefaultPATHWhenEmpty() throws {
        let root = try makeEtcDirectory(
            paths: "/usr/local/bin\n/usr/bin\n/bin",
            pathDEntries: ["40-homebrew": "/opt/homebrew/bin"]
        )
        let etc = (root as NSString).appendingPathComponent("etc")
        let env = ProcessEnvironment.sanitize([], etcDirectory: etc)
        let dict = envDict(from: env)
        let path = dict["PATH"] ?? ""
        for entry in ProcessEnvironment.defaultPATHEntries() {
            XCTAssertTrue(path.split(separator: ":").contains(Substring(entry)))
        }
    }

    func testSanitizeDoesNotDuplicateExistingPATHEntries() {
        let env = ProcessEnvironment.sanitize(["PATH=/opt/homebrew/bin:/usr/bin:/bin:/custom"])
        let dict = envDict(from: env)
        let path = dict["PATH"] ?? ""
        let parts = path.split(separator: ":").map(String.init)

        // Each entry appears exactly once.
        XCTAssertEqual(parts.filter { $0 == "/opt/homebrew/bin" }.count, 1)
        XCTAssertEqual(parts.filter { $0 == "/usr/bin" }.count, 1)
        XCTAssertEqual(parts.filter { $0 == "/bin" }.count, 1)
        XCTAssertEqual(parts.filter { $0 == "/custom" }.count, 1)

        // The user-specific entry is appended after all default entries.
        XCTAssertEqual(parts.last, "/custom")
    }

    func testSanitizePreservesInheritedCustomEnv() {
        let env = ProcessEnvironment.sanitize(["FOO=bar", "BAZ=qux"])
        let dict = envDict(from: env)
        XCTAssertEqual(dict["FOO"], "bar")
        XCTAssertEqual(dict["BAZ"], "qux")
    }

    // MARK: - defaultPATHEntries

    func testDefaultPATHEntriesReadsEtcPaths() throws {
        let root = try makeEtcDirectory(paths: "/one\n/two")
        let etc = (root as NSString).appendingPathComponent("etc")
        let entries = ProcessEnvironment.defaultPATHEntries(etcDirectory: etc)
        XCTAssertEqual(entries, ["/one", "/two"])
    }

    func testDefaultPATHEntriesReadsPathsDFilesInSortedOrder() throws {
        let root = try makeEtcDirectory(
            paths: "/one",
            pathDEntries: [
                "20-beta": "/three",
                "10-alpha": "/two",
            ]
        )
        let etc = (root as NSString).appendingPathComponent("etc")
        let entries = ProcessEnvironment.defaultPATHEntries(etcDirectory: etc)
        XCTAssertEqual(entries, ["/one", "/two", "/three"])
    }

    func testDefaultPATHEntriesUsesFallbackWhenSystemFilesMissing() {
        let bogus = (FileManager.default.temporaryDirectory.path as NSString)
            .appendingPathComponent(UUID().uuidString)
        let entries = ProcessEnvironment.defaultPATHEntries(etcDirectory: bogus)
        XCTAssertEqual(entries, ProcessEnvironment.fallbackPATHEntries)
    }

    func testDefaultPATHEntriesIgnoresEmptyLinesAndWhitespace() throws {
        let root = try makeEtcDirectory(paths: "  /one  \n\n  /two  \n")
        let etc = (root as NSString).appendingPathComponent("etc")
        let entries = ProcessEnvironment.defaultPATHEntries(etcDirectory: etc)
        XCTAssertEqual(entries, ["/one", "/two"])
    }

    // MARK: - mergedPATH

    func testMergedPATHPrependsDefaultsAndPreservesOriginalOrder() {
        let result = ProcessEnvironment.mergedPATH(
            currentPath: "/usr/bin:/bin:/custom",
            defaultEntries: ["/opt/homebrew/bin", "/usr/local/bin", "/usr/bin"]
        )
        XCTAssertEqual(result, "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/custom")
    }

    func testMergedPATHHandlesEmptyCurrentPath() {
        let result = ProcessEnvironment.mergedPATH(
            currentPath: "",
            defaultEntries: ["/usr/bin", "/bin"]
        )
        XCTAssertEqual(result, "/usr/bin:/bin")
    }

    func testMergedPATHHandlesEmptyDefaults() {
        let result = ProcessEnvironment.mergedPATH(
            currentPath: "/usr/bin:/bin",
            defaultEntries: []
        )
        XCTAssertEqual(result, "/usr/bin:/bin")
    }
}
