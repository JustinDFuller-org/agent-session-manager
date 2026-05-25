import XCTest

final class DragAndDropTests: BaseTestCase {
    override func setUp() {
        super.setUp()
        try? Data("\"head\"".utf8).write(to: UITestAppSupport.directory.appending(path: "worktree-base-ref.json"))
    }

    // MARK: - Tab Reordering

    func testDragTabForward() {
        createTab(named: "Alpha")
        createTab(named: "Beta")

        let alpha = app.buttons["tab-button-Alpha"].firstMatch
        let beta = app.buttons["tab-button-Beta"].firstMatch
        waitFor(alpha)
        waitFor(beta)

        XCTAssertLessThan(alpha.frame.minX, beta.frame.minX, "Alpha should start before Beta")

        alpha.click(forDuration: 0.5, thenDragTo: beta)
        screenshot("drag-tab-forward")

        XCTAssertLessThan(beta.frame.minX, alpha.frame.minX, "Beta should now appear before Alpha")
    }

    func testDragTabBackward() {
        createTab(named: "Alpha")
        createTab(named: "Beta")

        let alpha = app.buttons["tab-button-Alpha"].firstMatch
        let beta = app.buttons["tab-button-Beta"].firstMatch
        waitFor(alpha)
        waitFor(beta)

        XCTAssertLessThan(alpha.frame.minX, beta.frame.minX, "Alpha should start before Beta")

        beta.click(forDuration: 0.5, thenDragTo: alpha)
        screenshot("drag-tab-backward")

        XCTAssertLessThan(beta.frame.minX, alpha.frame.minX, "Beta should now appear before Alpha")
    }

    func testDragTabToSelf() {
        createTab(named: "Alpha")
        createTab(named: "Beta")

        let alpha = app.buttons["tab-button-Alpha"].firstMatch
        let beta = app.buttons["tab-button-Beta"].firstMatch
        waitFor(alpha)
        waitFor(beta)

        alpha.click(forDuration: 0.5, thenDragTo: alpha)
        screenshot("drag-tab-to-self")

        XCTAssertTrue(alpha.exists)
        XCTAssertTrue(beta.exists)
        XCTAssertLessThan(alpha.frame.minX, beta.frame.minX, "Order should be unchanged after dragging to self")
    }

    func testDragTabAcrossThree() {
        createTab(named: "Alpha")
        createTab(named: "Beta")
        createTab(named: "Gamma")

        let alpha = app.buttons["tab-button-Alpha"].firstMatch
        let beta = app.buttons["tab-button-Beta"].firstMatch
        let gamma = app.buttons["tab-button-Gamma"].firstMatch
        waitFor(alpha)
        waitFor(beta)
        waitFor(gamma)

        XCTAssertLessThan(alpha.frame.minX, beta.frame.minX, "Alpha should start first")
        XCTAssertLessThan(beta.frame.minX, gamma.frame.minX, "Beta should start second")

        alpha.click(forDuration: 0.5, thenDragTo: gamma)
        screenshot("drag-tab-across-three")

        XCTAssertLessThan(beta.frame.minX, alpha.frame.minX, "Beta should now precede Alpha")
    }

    // MARK: - Pane Reordering

    func testDragPaneForward() {
        createTab(named: "Work")
        createPane(named: "Foo")
        createPane(named: "Bar")

        let fooName = app.staticTexts["pane-name-Foo"].firstMatch
        let barName = app.staticTexts["pane-name-Bar"].firstMatch
        waitFor(fooName)
        waitFor(barName)

        XCTAssertLessThan(fooName.frame.minX, barName.frame.minX, "Foo should start before Bar")

        fooName.click(forDuration: 0.5, thenDragTo: barName)
        screenshot("drag-pane-forward")

        XCTAssertLessThan(barName.frame.minX, fooName.frame.minX, "Bar should now appear before Foo")
    }

    func testDragPaneBackward() {
        createTab(named: "Work")
        createPane(named: "Foo")
        createPane(named: "Bar")

        let fooName = app.staticTexts["pane-name-Foo"].firstMatch
        let barName = app.staticTexts["pane-name-Bar"].firstMatch
        waitFor(fooName)
        waitFor(barName)

        XCTAssertLessThan(fooName.frame.minX, barName.frame.minX, "Foo should start before Bar")

        barName.click(forDuration: 0.5, thenDragTo: fooName)
        screenshot("drag-pane-backward")

        XCTAssertLessThan(barName.frame.minX, fooName.frame.minX, "Bar should now appear before Foo")
    }

    func testDragPaneToSelf() {
        createTab(named: "Work")
        createPane(named: "Foo")
        createPane(named: "Bar")

        let fooName = app.staticTexts["pane-name-Foo"].firstMatch
        let barName = app.staticTexts["pane-name-Bar"].firstMatch
        waitFor(fooName)
        waitFor(barName)

        fooName.click(forDuration: 0.5, thenDragTo: fooName)
        screenshot("drag-pane-to-self")

        XCTAssertTrue(fooName.exists)
        XCTAssertTrue(barName.exists)
        XCTAssertLessThan(fooName.frame.minX, barName.frame.minX, "Order should be unchanged after dragging to self")
    }
}
