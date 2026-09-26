import XCTest

/// Launches the harness from a clean slate and drives it by the identifiers
/// its pages hand out.
@MainActor
class HarnessUITestCase: XCTestCase {

    var app: XCUIApplication!

    /// Extra launch arguments for a test, on top of the reset.
    var extraLaunchArguments: [String] { [] }

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-ResetState", "YES"] + extraLaunchArguments
        app.launch()
    }

    // MARK: - Lookups

    func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    var barTitle: XCUIElement { element("bar.title") }

    // MARK: - Actions

    /// Taps an element in a scroll view, scrolling it into view first.
    func tap(_ identifier: String, file: StaticString = #filePath, line: UInt = #line) {
        let target = element(identifier)
        XCTAssertTrue(target.waitForExistence(timeout: 5), "\(identifier) never appeared", file: file, line: line)
        scrollIntoView(target)
        target.tap()
    }

    func scrollIntoView(_ target: XCUIElement) {
        var attempts = 0
        while !isComfortablyOnScreen(target), attempts < 8 {
            app.swipeUp(velocity: .slow)
            attempts += 1
        }
    }

    /// Clear of the bottom bar, which sits over the end of every page.
    private func isComfortablyOnScreen(_ target: XCUIElement) -> Bool {
        guard target.exists, target.isHittable else { return false }
        let window = app.windows.firstMatch.frame
        return target.frame.maxY < window.maxY - 120 && target.frame.minY > window.minY + 50
    }

    func openFeature(_ rawValue: String, title: String, file: StaticString = #filePath, line: UInt = #line) {
        tap("catalog.\(rawValue)", file: file, line: line)
        expectBarTitle(title, file: file, line: line)
    }

    func goBack() {
        element("bar.back").tap()
    }

    func showTabs() {
        element("bar.tabs").tap()
    }

    // MARK: - Expectations

    func expectBarTitle(_ title: String, file: StaticString = #filePath, line: UInt = #line) {
        expectLabel(of: "bar.title", toBe: title, file: file, line: line)
    }

    func expectLabel(
        of identifier: String,
        toBe expected: String,
        timeout: TimeInterval = 5,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let target = element(identifier)
        let predicate = NSPredicate(format: "label == %@", expected)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: target)
        let result = XCTWaiter().wait(for: [expectation], timeout: timeout)
        XCTAssertEqual(
            result, .completed,
            "\(identifier) read \"\(target.exists ? target.label : "<missing>")\", expected \"\(expected)\"",
            file: file, line: line
        )
    }

    func expectGone(_ identifier: String, timeout: TimeInterval = 5, file: StaticString = #filePath, line: UInt = #line) {
        let target = element(identifier)
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: target)
        XCTAssertEqual(
            XCTWaiter().wait(for: [expectation], timeout: timeout), .completed,
            "\(identifier) is still there", file: file, line: line
        )
    }
}
