import XCTest

final class NavigationUITests: HarnessUITestCase {

    func testCatalogListsEveryFeature() {
        expectBarTitle("Catalog")
        for feature in [
            "navigation", "backHistory", "overlayPages", "media", "barItems",
            "switcher", "liveTabs", "restoration", "utilities"
        ] {
            let row = element("catalog.\(feature)")
            scrollIntoView(row)
            XCTAssertTrue(row.exists, "\(feature) is missing from the catalog")
        }
    }

    func testPushingAndPoppingRenameTheBar() {
        openFeature("navigation", title: "Navigation")
        expectLabel(of: "navigation.depth", toBe: "1")

        tap("navigation.link")
        expectBarTitle("Item 1")
        tap("item.pushNext")
        expectBarTitle("Item 2")

        goBack()
        expectBarTitle("Item 1")

        tap("item.popToRoot")
        expectBarTitle("Catalog")
        XCTAssertFalse(element("bar.back").isEnabled)
    }

    func testPushAndNavigateToARoot() {
        openFeature("navigation", title: "Navigation")

        tap("navigation.push")
        expectBarTitle("Item 100")
        goBack()
        expectBarTitle("Navigation")

        tap("navigation.navigate")
        expectBarTitle("Media Pages")
        goBack()
        expectBarTitle("Navigation")
    }

    func testSwipingBackFromTheEdge() {
        openFeature("navigation", title: "Navigation")
        tap("navigation.link")
        expectBarTitle("Item 1")

        let edge = app.coordinate(withNormalizedOffset: CGVector(dx: 0.01, dy: 0.5))
        edge.press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)))
        expectBarTitle("Navigation")
    }

    func testADeepLinkOpensInATabOfItsOwn() {
        openFeature("navigation", title: "Navigation")
        tap("navigation.deepLink")
        expectBarTitle("Item 7")

        goBack()
        expectBarTitle("Catalog")

        showTabs()
        XCTAssertTrue(app.navigationBars["2 Harness Tabs"].waitForExistence(timeout: 5))
    }

    func testTheBackButtonsHistoryPopsStraightToAnEarlierPage() {
        openFeature("backHistory", title: "Back History")
        tap("backHistory.push")
        expectBarTitle("Item 1")
        tap("item.pushNext")
        tap("item.pushNext")
        expectBarTitle("Item 3")

        element("bar.back").press(forDuration: 1.2)
        let entry = app.buttons["Back History"].firstMatch
        XCTAssertTrue(entry.waitForExistence(timeout: 5), "The back button's history menu never opened")
        XCTAssertTrue(app.buttons["Item 2"].exists)
        entry.tap()
        expectBarTitle("Back History")
    }

    func testTheOnPageBackHistoryListsNearestFirst() {
        openFeature("backHistory", title: "Back History")
        tap("backHistory.push")
        tap("item.pushNext")
        expectBarTitle("Item 2")

        tap("history.0")
        expectBarTitle("Catalog")
    }

    func testAnOverlayPageIsNamedByTheBarAndDismissedByItsBackButton() {
        openFeature("overlayPages", title: "Overlay Pages")
        expectLabel(of: "overlay.current", toBe: "None")

        tap("overlay.show.A")
        expectBarTitle("Overlay A")
        XCTAssertTrue(element("overlay.detailTitle").waitForExistence(timeout: 5))
        XCTAssertTrue(element("bar.back").isEnabled)

        goBack()
        expectBarTitle("Overlay Pages")
        expectGone("overlay.detailTitle")
        expectLabel(of: "overlay.current", toBe: "None")
    }
}
