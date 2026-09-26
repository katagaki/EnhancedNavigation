import Foundation
import Testing
@testable import EnhancedNavigation

@Suite("Tab lifecycle")
struct TabLifecycleTests {

    @Test func startsWithOneSelectedLiveTab() {
        let store = makeStore()
        #expect(store.tabs.count == 1)
        #expect(store.selectedTabID == store.tabs[0].id)
        #expect(store.liveTabIDs == [store.selectedTabID])
        #expect(!store.canCloseTabs)
    }

    @Test func openingATabSelectsItUnlessInBackground() {
        let store = makeStore()
        let first = store.selectedTabID

        let background = store.openTab(inBackground: true)
        #expect(store.selectedTabID == first)
        #expect(!store.isLive(background))

        let foreground = store.openTab(at: .library)
        #expect(store.selectedTabID == foreground)
        #expect(store.isLive(foreground))
        #expect(store.selectedTab.root == .library)
        #expect(store.tabs.map(\.id) == [first, background, foreground])
    }

    @Test func openingATabPushingAValueLandsOnIt() {
        let store = makeStore()
        store.openTab(pushing: 7)
        #expect(store.tabs.count == 2)
        #expect(store.selectedTab.path.count == 1)
        #expect(store.selectedTab.canGoBack)
    }

    @Test func closingTheSelectedTabSelectsItsNeighbour() {
        let store = makeStore()
        let first = store.selectedTabID
        let second = store.openTab()
        let third = store.openTab()
        var closed: [UUID] = []
        store.onTabsClosed = { closed += $0 }

        store.select(second)
        store.close(second)
        #expect(store.tabs.map(\.id) == [first, third])
        #expect(store.selectedTabID == third)
        #expect(!store.liveTabIDs.contains(second))
        #expect(closed == [second])

        store.close(third)
        #expect(store.selectedTabID == first)
    }

    @Test func theLastTabCannotBeClosed() {
        let store = makeStore()
        let only = store.selectedTabID
        store.close(only)
        #expect(store.tabs.map(\.id) == [only])
    }

    @Test func closingAllLeavesOneFreshTab() {
        let store = makeStore()
        let ids = [store.selectedTabID, store.openTab(), store.openTab()]
        var closed: [UUID] = []
        store.onTabsClosed = { closed = $0 }

        store.closeAll()
        #expect(store.tabs.count == 1)
        #expect(!ids.contains(store.selectedTabID))
        #expect(store.liveTabIDs == [store.selectedTabID])
        #expect(closed == ids)
    }

    @Test func movingATabTakesTheDestinationsPlace() {
        let store = makeStore()
        let a = store.selectedTabID
        let b = store.openTab()
        let c = store.openTab()

        store.moveTab(a, to: c)
        #expect(store.tabs.map(\.id) == [b, c, a])

        store.moveTab(a, to: b)
        #expect(store.tabs.map(\.id) == [a, b, c])

        store.moveTab(b, to: b)
        #expect(store.tabs.map(\.id) == [a, b, c])
    }

    @Test func liveTabsAreEvictedLeastRecentlyUsedFirst() {
        let store = makeStore(liveTabLimit: 2)
        let a = store.selectedTabID
        let b = store.openTab()
        let c = store.openTab()
        #expect(store.liveTabIDs == [b, c])

        store.select(b)
        store.select(a)
        #expect(store.liveTabIDs == [b, a])
    }

    @Test func aTabPlayingMediaIsNeverEvicted() {
        let store = makeStore(liveTabLimit: 2)
        let a = store.selectedTabID
        let player = FakePlayer()
        store.registerMediaPage(1, in: a, ownsMedia: { player.isPlaying }, stop: player.stop)

        let b = store.openTab()
        let c = store.openTab()
        #expect(store.hasPlayingMedia(in: a))
        #expect(store.liveTabIDs == [a, c])
        #expect(!store.isLive(b))
    }

    @Test func frequentlyVisitedRootsCountOpensAndNavigations() {
        let store = makeStore()
        store.openTab(at: .settings)
        store.openTab(at: .library)
        store.navigate(to: TestRoot.library)
        store.openTab(at: .home)

        #expect(store.frequentlyVisitedRoots == [.library, .settings])
        #expect(store.visitCounts["home"] == nil)
    }
}
