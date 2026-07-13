import XCTest

@testable import AgentSessionManager

final class TabOpenCodeConfigContentTests: XCTestCase {
    func testBuildOpenCodeConfigContentIsValidJSON() {
        let content = Tab.buildOpenCodeConfigContent()

        let data = Data(content.utf8)
        let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertNotNil(parsed)
    }

    func testBuildOpenCodeConfigContentContainsSafeDefaults() {
        let content = Tab.buildOpenCodeConfigContent()

        let data = Data(content.utf8)
        let parsed = try! JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertEqual(parsed["share"] as? String, "manual")
        XCTAssertEqual(parsed["autoupdate"] as? Bool, false)
    }

    func testBuildOpenCodeConfigContentIsCompact() {
        let content = Tab.buildOpenCodeConfigContent()

        XCTAssertFalse(content.contains(" "), "Config content should be compact JSON")
        XCTAssertLessThan(content.utf8.count, 1024, "Config content should stay well under the env-var budget")
    }
}
