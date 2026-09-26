import XCTest

final class PageFeatureUITests: HarnessUITestCase {

    func testMediaPlaysOnUnderOtherPagesAndStopsWhenPopped() {
        openFeature("media", title: "Media Pages")
        expectLabel(of: "media.status", toBe: "Nothing")

        tap("media.player1")
        expectBarTitle("Player 1")
        tap("player.toggle")
        expectLabel(of: "media.status", toBe: "Player 1")

        // Covered, not popped: it plays on.
        app.buttons["Push Item 1 over the player"].tap()
        expectBarTitle("Item 1")
        goBack()
        expectBarTitle("Player 1")
        expectLabel(of: "media.status", toBe: "Player 1")

        goBack()
        expectBarTitle("Media Pages")
        expectLabel(of: "media.status", toBe: "Nothing")
    }

    func testPagesPutTheirOwnItemsInTheBar() {
        openFeature("barItems", title: "Bar Items")
        XCTAssertTrue(element("barItems.leading").waitForExistence(timeout: 5))
        XCTAssertTrue(element("barItems.trailing").exists)
        XCTAssertTrue(element("barItems.accessory").exists)

        element("barItems.leading").tap()
        element("barItems.trailing").tap()
        element("barItems.accessory").tap()
        expectLabel(of: "barItems.taps", toBe: "3")

        toggle("barItems.leadingToggle")
        expectGone("barItems.leading")
        XCTAssertTrue(element("barItems.trailing").exists)
    }

    func testBarItemsBelongToTheirPage() {
        openFeature("barItems", title: "Bar Items")
        XCTAssertTrue(element("barItems.trailing").waitForExistence(timeout: 5))

        tap("barItems.push")
        expectBarTitle("Item 1")
        expectGone("barItems.trailing")
        expectGone("barItems.accessory")

        goBack()
        expectBarTitle("Bar Items")
        XCTAssertTrue(element("barItems.trailing").waitForExistence(timeout: 5))
        XCTAssertTrue(element("barItems.accessory").exists)
    }

    func testPageSlotsOnlyAnswerForTheirPage() {
        openFeature("utilities", title: "Utilities")
        let fill = app.buttons["Page 2 fills"]
        scrollIntoView(fill)
        fill.tap()
        expectLabel(of: "utilities.slot", toBe: "Share")

        app.buttons["Page 1 clears"].tap()
        expectLabel(of: "utilities.slot", toBe: "Share")

        app.buttons["Page 1"].tap()
        expectLabel(of: "utilities.slot", toBe: "Nothing")
        app.buttons["Page 2"].tap()

        app.buttons["Page 2 clears"].tap()
        expectLabel(of: "utilities.slot", toBe: "Nothing")
    }

    func testTheFrameClockSettles() {
        openFeature("utilities", title: "Utilities")
        tap("utilities.frameClock")
        let result = element("utilities.frameClockResult")
        let settled = NSPredicate(format: "label ENDSWITH %@", "ms")
        wait(for: [XCTNSPredicateExpectation(predicate: settled, object: result)], timeout: 5)
    }

    private func toggle(_ identifier: String) {
        let toggle = app.switches[identifier].firstMatch
        scrollIntoView(toggle)
        // The switch itself, not the label: a tap on the label no longer flips it.
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
    }
}
