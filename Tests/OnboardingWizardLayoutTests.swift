import XCTest

@testable import AgentSessionManager

final class OnboardingWizardLayoutTests: XCTestCase {
    func testCompactStepsStayContentSized() throws {
        let compactSteps: [OnboardingWizardView.Step] = [.welcome, .shell, .tools]

        for step in compactSteps {
            let layout = try XCTUnwrap(OnboardingWizardView.stepLayouts[step])
            XCTAssertEqual(layout.minWidth, 520)
            XCTAssertEqual(layout.idealWidth, 520)
            XCTAssertEqual(layout.maxWidth, 520)
            XCTAssertNil(layout.fixedSheetHeight)
            XCTAssertNil(layout.editorMinHeight)
            XCTAssertNil(layout.editorMaxHeight)
        }
    }

    func testStatusLineStepUsesTallEditorLayout() throws {
        let layout = try XCTUnwrap(OnboardingWizardView.stepLayouts[.statusLine])
        XCTAssertEqual(layout.minWidth, 760)
        XCTAssertEqual(layout.idealWidth, 760)
        XCTAssertNil(layout.maxWidth)
        XCTAssertEqual(layout.fixedSheetHeight, 700)
        XCTAssertEqual(layout.editorMinHeight, 420)
        XCTAssertNil(layout.editorMaxHeight)
    }

    func testCliFlagsStepUsesTallEditorLayout() throws {
        let layout = try XCTUnwrap(OnboardingWizardView.stepLayouts[.cliFlags])
        XCTAssertEqual(layout.minWidth, 760)
        XCTAssertEqual(layout.idealWidth, 760)
        XCTAssertNil(layout.maxWidth)
        XCTAssertEqual(layout.fixedSheetHeight, 720)
        XCTAssertEqual(layout.editorMinHeight, 440)
        XCTAssertNil(layout.editorMaxHeight)
    }

    func testProfilesStepStaysWideWithoutFixedSheetHeight() throws {
        let layout = try XCTUnwrap(OnboardingWizardView.stepLayouts[.profiles])
        XCTAssertEqual(layout.minWidth, 760)
        XCTAssertEqual(layout.idealWidth, 760)
        XCTAssertNil(layout.maxWidth)
        XCTAssertNil(layout.fixedSheetHeight)
        XCTAssertNil(layout.editorMinHeight)
        XCTAssertEqual(layout.editorMaxHeight, 380)
    }
}
