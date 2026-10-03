import UIKit
import XCTest

final class AdaptiveTabsUITests: HarnessUITestCase {

    func testTabChromeAndOverviewOnThisDevice() {
        if UIDevice.current.userInterfaceIdiom == .pad {
            XCTAssertTrue(app.buttons["New Tab"].waitForExistence(timeout: 5))
            XCTAssertFalse(element("bar.tabs").exists)
            XCTAssertFalse(app.buttons["Close Tab"].exists)

            app.buttons["New Tab"].tap()
            XCTAssertTrue(app.buttons["Close Tab"].waitForExistence(timeout: 5))

            app.buttons["Show All Tabs"].tap()
            XCTAssertTrue(app.navigationBars["2 Harness Tabs"].waitForExistence(timeout: 5))
            XCTAssertTrue(app.buttons["New Harness Tab"].exists)
            app.buttons["Done"].tap()

            app.buttons["Close Tab"].tap()
            XCTAssertFalse(app.buttons["Close Tab"].exists)
        } else {
            XCTAssertFalse(app.buttons["New Tab"].exists)
            showTabs()
            XCTAssertTrue(app.navigationBars["1 Harness Tab"].waitForExistence(timeout: 5))
            XCTAssertTrue(app.buttons["New Harness Tab"].exists)
        }
    }

    func testIPadPageItemsUseTheTopBar() {
        guard UIDevice.current.userInterfaceIdiom == .pad else { return }

        let feature = element("catalog.barItems")
        XCTAssertTrue(feature.waitForExistence(timeout: 5))
        feature.tap()

        XCTAssertFalse(element("bar.tabs").exists)
        XCTAssertTrue(element("barItems.leading").waitForExistence(timeout: 5))
        XCTAssertTrue(element("barItems.trailing").exists)
        XCTAssertTrue(element("barItems.accessory").exists)

        element("barItems.leading").tap()
        expectLabel(of: "barItems.taps", toBe: "1")
    }

    func testPageLocalStateSurvivesOverview() {
        tap("catalog.barItems")
        XCTAssertTrue(element("barItems.leading").waitForExistence(timeout: 5))
        element("barItems.leading").tap()
        expectLabel(of: "barItems.taps", toBe: "1")

        if UIDevice.current.userInterfaceIdiom == .pad {
            app.buttons["Show All Tabs"].tap()
        } else {
            showTabs()
        }
        XCTAssertTrue(app.buttons["Done"].waitForExistence(timeout: 5))
        app.buttons["Done"].tap()

        expectLabel(of: "barItems.taps", toBe: "1")
        // A second tap also checks that the registered action still belongs
        // to the same mounted page, rather than an obsolete state binding.
        XCTAssertTrue(element("barItems.leading").waitForExistence(timeout: 5))
        element("barItems.leading").tap()
        expectLabel(of: "barItems.taps", toBe: "2")
    }

    func testIPadNewTabsStayVisibleWhenStripOverflows() throws {
        guard UIDevice.current.userInterfaceIdiom == .pad else { throw XCTSkip("Requires iPad") }
        for _ in 0..<10 { app.buttons["New Tab"].tap() }

        let selected = app.buttons.matching(NSPredicate(
            format: "identifier BEGINSWITH 'adaptive.tab.' AND selected == true"
        )).firstMatch
        XCTAssertTrue(selected.waitForExistence(timeout: 5))
        XCTAssertTrue(selected.isHittable)
        XCTAssertTrue(app.buttons["Close Tab"].isHittable)

        let firstTabID = app.buttons.matching(NSPredicate(
            format: "identifier BEGINSWITH 'adaptive.tab.'"
        )).element(boundBy: 0).identifier
        app.buttons["Show All Tabs"].tap()
        let card = app.buttons["switcher.card"].firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        card.tap()
        let firstTab = app.buttons[firstTabID]
        XCTAssertTrue(firstTab.waitForExistence(timeout: 5))
        XCTAssertTrue(firstTab.isSelected)
        XCTAssertTrue(firstTab.isHittable)
    }

    func testIPadPageKeepsItsNavigationAfterOverview() {
        guard UIDevice.current.userInterfaceIdiom == .pad else { return }

        tap("catalog.navigation")
        XCTAssertTrue(element("navigation.push").waitForExistence(timeout: 5))
        tap("navigation.push")
        XCTAssertTrue(element("item.pushNext").waitForExistence(timeout: 5))

        app.buttons["Show All Tabs"].tap()
        XCTAssertTrue(app.navigationBars["1 Harness Tab"].waitForExistence(timeout: 5))
        app.buttons["Done"].tap()

        XCTAssertTrue(element("item.pushNext").waitForExistence(timeout: 5))
    }

    func testIPadOverviewCardsFollowOrientation() {
        guard UIDevice.current.userInterfaceIdiom == .pad else { return }
        defer { XCUIDevice.shared.orientation = .portrait }

        XCUIDevice.shared.orientation = .portrait
        app.buttons["Show All Tabs"].tap()

        let card = app.buttons["switcher.card"].firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        XCTAssertGreaterThan(card.frame.height, card.frame.width)

        XCUIDevice.shared.orientation = .landscapeLeft
        let landscapeCard = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in card.frame.width > card.frame.height },
            object: card
        )
        XCTAssertEqual(XCTWaiter.wait(for: [landscapeCard], timeout: 5), .completed)
    }
}

final class NarrowAdaptiveTabsUITests: HarnessUITestCase {
    override var extraLaunchArguments: [String] { ["-AdaptivePreviewWidth", "375"] }

    func testIPadNarrowToolbarKeepsEveryActionAccessible() throws {
        guard UIDevice.current.userInterfaceIdiom == .pad else { throw XCTSkip("Requires iPad") }
        tap("catalog.barItems")
        let controls = [element("barItems.leading"), element("barItems.trailing"),
                        element("barItems.accessory"), app.buttons["Back"],
                        app.buttons["New Tab"], app.buttons["Show All Tabs"]]
        for control in controls {
            XCTAssertTrue(control.waitForExistence(timeout: 5))
            XCTAssertTrue(control.isHittable)
            let left = (app.windows.firstMatch.frame.width - 375) / 2
            XCTAssertGreaterThanOrEqual(control.frame.minX, left)
            XCTAssertLessThanOrEqual(control.frame.maxX, left + 375)
        }
        // Each declared page action must still update the page's state.
        XCTAssertTrue(element("barItems.leading").waitForExistence(timeout: 5))
        element("barItems.leading").tap()
        element("barItems.trailing").tap()
        element("barItems.accessory").tap()
        expectLabel(of: "barItems.taps", toBe: "3")
        let first = element("barItems.accessory").frame
        let second = app.buttons["Show All Tabs"].frame
        XCTAssertLessThan(first.maxY, second.minY)
    }
}
