import XCTest

@testable import AgentSessionManager

final class DistributionChannelTests: XCTestCase {
    func testDMGChannelKey() {
        XCTAssertEqual(DistributionChannel.from(infoDictionary: ["ASMDistributionChannel": "dmg"]), .dmg)
    }

    func testSourceMainChannelKey() {
        XCTAssertEqual(
            DistributionChannel.from(infoDictionary: ["ASMDistributionChannel": "sourceMain"]), .sourceMain)
    }

    func testMainProvenanceInfersSourceMain() {
        XCTAssertEqual(
            DistributionChannel.from(infoDictionary: [
                "ASMSourceCommit": "abc123",
                "ASMSourceBranch": "main",
            ]),
            .sourceMain)
    }

    func testFeatureBranchProvenanceIsUnknown() {
        XCTAssertEqual(
            DistributionChannel.from(infoDictionary: [
                "ASMSourceCommit": "abc123",
                "ASMSourceBranch": "feature",
            ]),
            .unknown)
    }

    func testDMGKeyOverridesMainProvenance() {
        XCTAssertEqual(
            DistributionChannel.from(infoDictionary: [
                "ASMDistributionChannel": "dmg",
                "ASMSourceBranch": "main",
                "ASMSourceCommit": "abc123",
            ]),
            .dmg)
    }

    func testEmptyDictionaryIsUnknown() {
        XCTAssertEqual(DistributionChannel.from(infoDictionary: [:]), .unknown)
    }

    func testUnknownChannelKeyIsUnknown() {
        XCTAssertEqual(
            DistributionChannel.from(infoDictionary: ["ASMDistributionChannel": "beta"]), .unknown)
    }
}
