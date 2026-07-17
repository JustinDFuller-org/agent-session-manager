import XCTest

@testable import AgentSessionManager

final class TabHostEnvironmentTests: XCTestCase {
    func testHostEnvironmentForChildProcessDropsCoreFoundationPrivateVars() {
        let env = Tab.hostEnvironmentForChildProcess()

        XCTAssertFalse(
            env.contains { $0.hasPrefix("__CF") },
            "CoreFoundation-private vars (e.g. __CFBundleIdentifier) must not reach a pane's shell"
        )
    }

    func testHostEnvironmentForChildProcessKeepsOrdinaryVars() {
        let env = Tab.hostEnvironmentForChildProcess()

        XCTAssertTrue(env.contains { $0.hasPrefix("PATH=") })
    }
}
