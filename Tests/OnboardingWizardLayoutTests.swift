import XCTest

@testable import AgentSessionManager

final class OnboardingWizardLayoutTests: XCTestCase {
    func testCompactStepsUseCompactLayout() {
        let compactSteps: [OnboardingWizardView.Step] = [.welcome, .shell, .tools]

        for step in compactSteps {
            XCTAssertEqual(OnboardingWizardView.stepLayouts[step], .compact)
        }
    }

    func testExpandedStepsUseSharedExpandedPresentation() throws {
        let expandedSteps: [OnboardingWizardView.Step] = [.statusLine, .cliFlags, .profiles]

        for step in expandedSteps {
            let layout = try XCTUnwrap(OnboardingWizardView.stepLayouts[step])
            XCTAssertEqual(layout.minWidth, 760)
            XCTAssertEqual(layout.idealWidth, 760)
            XCTAssertNil(layout.maxWidth)
            XCTAssertEqual(layout.minHeight, 620)
            XCTAssertEqual(layout.idealHeight, 620)
        }
    }

    func testExpandedStepsUseExpectedEditorViewportHeights() throws {
        XCTAssertEqual(try XCTUnwrap(OnboardingWizardView.stepLayouts[.statusLine]).editorMinHeight, 420)
        XCTAssertEqual(try XCTUnwrap(OnboardingWizardView.stepLayouts[.cliFlags]).editorMinHeight, 440)
        XCTAssertEqual(try XCTUnwrap(OnboardingWizardView.stepLayouts[.profiles]).editorMinHeight, 420)
    }
}
