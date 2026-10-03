import UIKit
import XCTest

final class OmniboxSwipeUITests: HarnessUITestCase {
    override var extraLaunchArguments: [String] { ["-LiveTabLimit", "2"] }

    private var isPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }
    private var omnibox: XCUIElement { element(isPad ? "adaptive.omnibox" : "bar.omnibox") }

    private func expectPage(_ title: String, file: StaticString = #filePath, line: UInt = #line) {
        if isPad {
            let selected = app.buttons.matching(NSPredicate(
                format: "identifier BEGINSWITH 'adaptive.tab.' AND selected == true"
            )).firstMatch
            let expectation = XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "label CONTAINS %@", title), object: selected
            )
            XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 5), .completed, file: file, line: line)
        } else {
            expectBarTitle(title, file: file, line: line)
        }
    }

    private func swipe(left: Bool) {
        XCTAssertTrue(omnibox.waitForExistence(timeout: 5))
        let start = omnibox.coordinate(withNormalizedOffset: CGVector(dx: left ? 0.85 : 0.15, dy: 0.5))
        let end = omnibox.coordinate(withNormalizedOffset: CGVector(dx: left ? 0.15 : 0.85, dy: 0.5))
        start.press(forDuration: 0.05, thenDragTo: end)
    }

    func testSwipesFollowTabOrderAndStopAtBothEnds() {
        tap("catalog.switcher")
        tap("switcher.openFour")
        expectPage("Tab Switcher")
        swipe(left: false)
        expectPage("Tab Switcher")

        for title in ["Media Pages", "Bar Items", "Live Tabs", "Utilities"] {
            swipe(left: true)
            expectPage(title)
        }
        swipe(left: true)
        expectPage("Utilities")
        // With only two live tabs, this also revisits tabs after eviction.
        for title in ["Live Tabs", "Bar Items", "Media Pages", "Tab Switcher"] {
            swipe(left: false)
            expectPage(title)
        }
        expectLabel(of: "switcher.order", toBe: "Tab Switcher, Media Pages, Bar Items, Live Tabs, Utilities")
    }

    func testShortAndVerticalDragsDoNotSwitchTabs() {
        swipe(left: true)
        swipe(left: false)
        XCTAssertTrue(element("catalog.switcher").exists)
        tap("catalog.switcher")
        // A single tab with navigation history must not turn an omnibox
        // swipe into a back navigation gesture either.
        swipe(left: true)
        swipe(left: false)
        XCTAssertTrue(element("switcher.openFour").exists)
        tap("switcher.openFour")
        let center = omnibox.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        center.press(forDuration: 0.05, thenDragTo: center.withOffset(CGVector(dx: -20, dy: 0)))
        expectPage("Tab Switcher")
        center.press(forDuration: 0.05, thenDragTo: center.withOffset(CGVector(dx: 0, dy: -90)))
        expectPage("Tab Switcher")
    }

    func testSwipingBackPreservesNavigationAndBarActions() {
        tap("catalog.barItems")
        element("barItems.leading").tap()
        expectLabel(of: "barItems.taps", toBe: "1")
        if isPad {
            app.buttons["New Tab"].tap()
        } else {
            showTabs()
            app.buttons["New Harness Tab"].tap()
        }
        expectPage("Catalog")
        swipe(left: false)
        expectPage("Bar Items")
        expectLabel(of: "barItems.taps", toBe: "1")
        element("barItems.accessory").tap()
        element("barItems.trailing").tap()
        expectLabel(of: "barItems.taps", toBe: "3")
        (isPad ? app.buttons["Back"] : element("bar.back")).tap()
        XCTAssertTrue(element("catalog.navigation").waitForExistence(timeout: 5))
        tap("catalog.navigation")
        tap("navigation.push")
        XCTAssertTrue(element("item.pushNext").waitForExistence(timeout: 5))
        swipe(left: true)
        expectPage("Catalog")
        swipe(left: false)
        expectPage("Item 100")
        XCTAssertTrue(element("item.pushNext").exists)
    }
}
