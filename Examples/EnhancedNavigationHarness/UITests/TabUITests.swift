import XCTest

final class SwitcherUITests: HarnessUITestCase {

    func testTheSwitcherOpensNewTabsAndClosesThem() {
        showTabs()
        XCTAssertTrue(app.navigationBars["1 Harness Tab"].waitForExistence(timeout: 5))

        app.buttons["New Harness Tab"].tap()
        expectBarTitle("Catalog")

        showTabs()
        XCTAssertTrue(app.navigationBars["2 Harness Tabs"].waitForExistence(timeout: 5))
        app.buttons["Close Harness Tab"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["1 Harness Tab"].waitForExistence(timeout: 5))
    }

    func testTheInspectorHangsOffTheSwitcher() {
        showTabs()
        let inspector = element("switcher.inspector")
        XCTAssertTrue(inspector.waitForExistence(timeout: 5))
        inspector.tap()
        expectLabel(of: "inspector.tabCount", toBe: "1")
        expectLabel(of: "inspector.switcher", toBe: "Yes")
    }

    func testTabsAreReorderedByDraggingOneOntoAnother() throws {
        openFeature("switcher", title: "Tab Switcher")
        tap("switcher.openFour")
        expectLabel(of: "switcher.order", toBe: "Tab Switcher, Media Pages, Bar Items, Live Tabs, Utilities")

        tap("switcher.show")
        XCTAssertTrue(app.navigationBars["5 Harness Tabs"].waitForExistence(timeout: 5))

        let dragged = card(named: "Utilities")
        let destination = card(named: "Tab Switcher")
        XCTAssertTrue(dragged.waitForExistence(timeout: 5))
        dragged.press(
            forDuration: 1.0,
            thenDragTo: destination,
            withVelocity: .slow,
            thenHoldForDuration: 0.8
        )

        // Back to the page, whose order read-out follows the store.
        destination.tap()
        expectLabel(of: "switcher.order", toBe: "Utilities, Tab Switcher, Media Pages, Bar Items, Live Tabs")
    }

    func testSwipingACardAwayClosesItsTab() {
        openFeature("switcher", title: "Tab Switcher")
        tap("switcher.openFour")
        tap("switcher.show")
        XCTAssertTrue(app.navigationBars["5 Harness Tabs"].waitForExistence(timeout: 5))

        let doomed = card(named: "Bar Items")
        doomed.swipeLeft(velocity: .fast)
        XCTAssertTrue(app.navigationBars["4 Harness Tabs"].waitForExistence(timeout: 5))
    }

    func testAScrollThatDriftsSidewaysStillScrollsTheGrid() {
        openFeature("switcher", title: "Tab Switcher")
        tap("switcher.openFour")
        tap("switcher.openFour")
        tap("switcher.show")
        XCTAssertTrue(app.navigationBars["9 Harness Tabs"].waitForExistence(timeout: 5))

        let first = card(named: "Tab Switcher")
        XCTAssertTrue(first.waitForExistence(timeout: 5))
        let topBefore = first.frame.minY

        let grid = app.scrollViews.firstMatch
        let start = grid.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.75))
        start.press(
            forDuration: 0.05,
            thenDragTo: start.withOffset(CGVector(dx: -40, dy: -300)),
            withVelocity: .default,
            thenHoldForDuration: 0.2
        )

        XCTAssertLessThan(first.frame.minY, topBefore - 100)
        XCTAssertTrue(app.navigationBars["9 Harness Tabs"].exists)
    }

    func testTheSelectedCardIsInViewWhenTheSwitcherOpens() {
        openFeature("switcher", title: "Tab Switcher")
        for _ in 0..<4 {
            tap("switcher.openFour")
        }
        tap("switcher.show")
        XCTAssertTrue(app.navigationBars["17 Harness Tabs"].waitForExistence(timeout: 5))

        // The last tab, from the far end of the grid.
        let grid = app.scrollViews.firstMatch
        for _ in 0..<6 {
            grid.swipeUp(velocity: .fast)
        }
        cards.allElementsBoundByIndex.last(where: \.isHittable)?.tap()
        expectBarTitle("Utilities")

        // Left scrolled back to the top: the next visit still opens on it.
        showTabs()
        XCTAssertTrue(selectedCard.waitForExistence(timeout: 5))
        for _ in 0..<6 {
            grid.swipeDown(velocity: .fast)
        }
        app.buttons["Done"].tap()
        expectBarTitle("Utilities")
        showTabs()
        expectSelectedCardOnScreen()

        // And after a relaunch, where nothing has scrolled the grid yet.
        app.buttons["Done"].tap()
        expectBarTitle("Utilities")
        Thread.sleep(forTimeInterval: 1)
        app.terminate()
        app.launchArguments = []
        app.launch()
        expectBarTitle("Utilities")
        showTabs()
        expectSelectedCardOnScreen()
    }

    private var cards: XCUIElementQuery {
        app.buttons.matching(identifier: "switcher.card")
    }

    private var selectedCard: XCUIElement {
        cards.matching(NSPredicate(format: "selected == true")).firstMatch
    }

    private func expectSelectedCardOnScreen(file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(app.navigationBars["17 Harness Tabs"].waitForExistence(timeout: 5), file: file, line: line)
        XCTAssertTrue(selectedCard.waitForExistence(timeout: 5), "the selected card was never built", file: file, line: line)
        XCTAssertTrue(
            app.windows.firstMatch.frame.contains(selectedCard.frame),
            "the selected card sits at \(selectedCard.frame)", file: file, line: line
        )
    }

    /// A card is a button labelled with the tab's page.
    private func card(named title: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", title)).firstMatch
    }
}

final class LiveTabUITests: HarnessUITestCase {

    override var extraLaunchArguments: [String] { ["-LiveTabLimit", "2"] }

    func testOnlyTheMostRecentTabsStayMounted() {
        openFeature("liveTabs", title: "Live Tabs")
        expectLabel(of: "liveTabs.count", toBe: "1 of 2")

        tap("feature.openInNewTab")
        expectBarTitle("Live Tabs")
        expectLabel(of: "liveTabs.count", toBe: "2 of 2")

        tap("feature.openInNewTab")
        expectLabel(of: "liveTabs.count", toBe: "2 of 2")
        XCTAssertTrue(app.staticTexts["Evicted"].waitForExistence(timeout: 5))
    }
}

final class RestorationUITests: HarnessUITestCase {

    func testEveryTabComesBackDownToThePageItWasLeftOn() {
        openFeature("restoration", title: "Restoration")
        tap("restoration.push")
        tap("item.pushNext")
        expectBarTitle("Item 2")

        // Written on the next pass; give it one before pulling the plug.
        Thread.sleep(forTimeInterval: 1)
        app.terminate()
        app.launchArguments = []
        app.launch()

        expectBarTitle("Item 2")
        goBack()
        expectBarTitle("Item 1")
        goBack()
        expectBarTitle("Restoration")
        goBack()
        expectBarTitle("Catalog")
    }

    func testASimulatedRelaunchRebuildsTheStack() {
        openFeature("restoration", title: "Restoration")
        expectLabel(of: "restoration.launch", toBe: "1")

        tap("restoration.relaunch")
        expectLabel(of: "restoration.launch", toBe: "2")
        expectBarTitle("Restoration")

        goBack()
        expectBarTitle("Catalog")
    }

    func testFrequentlyVisitedRootsAreListedInTheCatalog() {
        openFeature("media", title: "Media Pages")
        tap("feature.openInNewTab")
        expectBarTitle("Media Pages")

        showTabs()
        XCTAssertTrue(app.navigationBars["2 Harness Tabs"].waitForExistence(timeout: 5))
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Media Pages")).firstMatch.tap()
        expectBarTitle("Media Pages")
        goBack()
        expectBarTitle("Catalog")

        let frequent = element("frequent.feature.media")
        scrollIntoView(frequent)
        XCTAssertTrue(frequent.exists)
    }
}
