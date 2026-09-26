import Foundation
import SwiftUI
import Testing
@testable import EnhancedNavigation

@Suite("Navigation and page history")
struct NavigationTests {

    private func storeOnHome() -> TestStore {
        let store = makeStore()
        store.setPageIdentity(.home, for: store.selectedTabID)
        return store
    }

    @Test func goingBackNamesThePageUnderneath() {
        let store = storeOnHome()
        store.pushPage(1)
        store.pushPage(2)
        #expect(store.selectedTab.pageIdentity == .item(2))

        store.goBack()
        #expect(store.selectedTab.path.count == 1)
        #expect(store.selectedTab.pageIdentity == .item(1))

        store.goBack()
        #expect(store.selectedTab.pageIdentity == .home)
        #expect(!store.selectedTab.canGoBack)
    }

    @Test func poppingToADepthNamesThePageThere() {
        let store = storeOnHome()
        for number in 1...4 { store.pushPage(number) }

        store.popTo(depth: 1)
        #expect(store.selectedTab.path.count == 1)
        #expect(store.selectedTab.pageIdentity == .item(1))
    }

    @Test func backHistoryListsNearestFirst() {
        let store = storeOnHome()
        for number in 1...3 { store.pushPage(number) }

        let entries = store.backHistory(for: store.selectedTabID)
        #expect(entries.map(\.depth) == [2, 1, 0])
        #expect(entries.map(\.identity) == [.item(2), .item(1), .home])
    }

    @Test func pushingAfterAPopDropsTheOldBranch() {
        let store = storeOnHome()
        store.pushPage(1)
        store.pushPage(2)
        store.goBack()
        #expect(store.pageHistories[store.selectedTabID]?.count == 3)

        store.pushPage(9)
        #expect(store.pageHistories[store.selectedTabID] == [.home, .item(1), .item(9)])
    }

    @Test func aLateReportFromAPoppedPageIsRefused() {
        let store = storeOnHome()
        store.pushPage(1)
        store.pushPage(2)
        store.goBack()

        // SwiftUI re-runs onAppear on pages as a pop unwinds.
        store.setPageIdentity(.item(2), for: store.selectedTabID)
        #expect(store.selectedTab.pageIdentity == .item(1))
    }

    @Test func thePathBindingTracksPopsFromTheStack() {
        let store = storeOnHome()
        store.pushPage(1)
        store.pushPage(2)
        let binding = store.pathBinding(for: store.selectedTabID)

        var path = binding.wrappedValue
        path.removeLast()
        binding.wrappedValue = path
        #expect(store.selectedTab.pageIdentity == .item(1))
    }

    @Test func navigatingToARootPushesIt() {
        let store = storeOnHome()
        store.navigate(to: TestRoot.library)
        #expect(store.selectedTab.path.count == 1)
        #expect(store.visitCounts["library"] == 1)
    }

    @Test func aSwipeBackFreezesTheChromeUntilItEnds() {
        let store = storeOnHome()
        store.pushPage(1)
        let tabID = store.selectedTabID

        store.beginInteractivePop()
        // The stack pops the path as soon as the swipe starts.
        store.pathBinding(for: tabID).wrappedValue = NavigationPath()
        #expect(store.selectedTab.pageIdentity == .home)
        #expect(store.displayedTab(for: tabID).pageIdentity == .item(1))
        #expect(store.displayedCanGoBack(for: tabID))

        store.endInteractivePop(cancelled: true)
        #expect(!store.isInteractivelyPopping)
        #expect(store.selectedTab.pageIdentity == .item(1))
    }

    @Test func aPushSettlesASwipeWhoseEndWentUnheard() {
        let store = storeOnHome()
        store.pushPage(1)
        store.beginInteractivePop()
        store.push(2)
        #expect(!store.isInteractivelyPopping)
    }
}

@Suite("Overlay pages")
struct OverlayPageTests {

    @Test func anOverlayPageNamesTheTabAndIsDismissedByBack() {
        let store = makeStore()
        let tabID = store.selectedTabID
        store.setPageIdentity(.home, for: tabID)
        var isPresented = true
        let overlayID = UUID()
        store.setOverlayPage(
            OverlayPage(id: overlayID, identity: .item(42), dismiss: { isPresented = false }),
            id: overlayID,
            for: tabID
        )

        #expect(store.displayedTab(for: tabID).pageIdentity == .item(42))
        #expect(store.displayedCanGoBack(for: tabID))
        #expect(store.displayedOverlayPage?.id == overlayID)

        store.goBack()
        #expect(!isPresented)
        #expect(store.displayedOverlayPage == nil)
        #expect(store.displayedTab(for: tabID).pageIdentity == .home)
        #expect(!store.displayedCanGoBack(for: tabID))
    }

    @Test func aPathChangeClearsOverlayPages() {
        let store = makeStore()
        let tabID = store.selectedTabID
        let overlayID = UUID()
        store.setOverlayPage(
            OverlayPage(id: overlayID, identity: .item(1), dismiss: {}),
            id: overlayID,
            for: tabID
        )
        var path = NavigationPath()
        path.append(3)
        store.pathBinding(for: tabID).wrappedValue = path
        #expect(store.overlayPages[tabID] == nil)
    }
}

@Suite("Media pages")
struct MediaPageTests {

    @Test func poppingAPlayerPageStopsItsMedia() {
        let store = makeStore()
        let tabID = store.selectedTabID
        store.setPageIdentity(.home, for: tabID)
        store.pushPage(1)
        let player = FakePlayer()
        store.registerMediaPage(1, in: tabID, ownsMedia: { player.isPlaying }, stop: player.stop)

        store.pushPage(2)
        #expect(player.isPlaying)

        store.goBack()
        #expect(player.isPlaying)

        store.goBack()
        #expect(!player.isPlaying)
        #expect(player.stopCount == 1)
    }

    @Test func mediaWaitsForASwipeBackToCommit() {
        let store = makeStore()
        let tabID = store.selectedTabID
        store.setPageIdentity(.home, for: tabID)
        store.pushPage(1)
        let player = FakePlayer()
        store.registerMediaPage(1, in: tabID, ownsMedia: { player.isPlaying }, stop: player.stop)

        store.beginInteractivePop()
        store.pathBinding(for: tabID).wrappedValue = NavigationPath()
        #expect(player.isPlaying)

        store.endInteractivePop(cancelled: false)
        #expect(!player.isPlaying)
    }

    @Test func closingATabStopsItsMedia() {
        let store = makeStore()
        let tabID = store.selectedTabID
        store.openTab()
        let player = FakePlayer()
        store.registerMediaPage(1, in: tabID, ownsMedia: { player.isPlaying }, stop: player.stop)

        store.close(tabID)
        #expect(!player.isPlaying)
    }
}
