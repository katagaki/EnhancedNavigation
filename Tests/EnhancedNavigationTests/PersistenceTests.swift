import Foundation
import SwiftUI
import Testing
@testable import EnhancedNavigation

@Suite("Persistence and restoration")
struct PersistenceTests {

    @Test func tabsAndSelectionSurviveARelaunch() async {
        let configuration = makeConfiguration()
        let store = TestStore(configuration: configuration)
        let first = store.selectedTabID
        let second = store.openTab(at: .library)
        store.select(first)
        await store.flushPersistence()

        let restored = TestStore.restored(configuration: configuration)
        #expect(restored.tabs.map(\.id) == [first, second])
        #expect(restored.tabs.map(\.root) == [.home, .library])
        #expect(restored.selectedTabID == first)
    }

    @Test func aTabIsRebuiltDownToThePageItWasLeftOn() async {
        let configuration = makeConfiguration()
        let store = TestStore(configuration: configuration)
        let tabID = store.selectedTabID
        store.setPageIdentity(.home, for: tabID)
        for number in 1...3 { store.pushPage(number) }
        store.goBack()
        await store.flushPersistence()

        let restored = TestStore.restored(configuration: configuration)
        #expect(restored.tabsAwaitingPathRestore == [tabID])
        #expect(restored.tab(tabID)?.pageIdentity == .item(2))

        var rebuilt: [Int] = []
        restored.restorePathIfNeeded(for: tabID) { token, path in
            rebuilt.append(token)
            path.append(token)
            return true
        }
        // The popped page is not pushed back.
        #expect(rebuilt == [1, 2])
        #expect(restored.tab(tabID)?.path.count == 2)
        #expect(restored.tabsAwaitingPathRestore.isEmpty)
    }

    @Test func aRebuildStopsAtAPageThatIsGone() async {
        let configuration = makeConfiguration()
        let store = TestStore(configuration: configuration)
        let tabID = store.selectedTabID
        store.setPageIdentity(.home, for: tabID)
        for number in 1...3 { store.pushPage(number) }
        await store.flushPersistence()

        let restored = TestStore.restored(configuration: configuration)
        restored.restorePathIfNeeded(for: tabID) { token, path in
            guard token != 2 else { return false }
            path.append(token)
            return true
        }
        #expect(restored.tab(tabID)?.path.count == 1)
        #expect(restored.tab(tabID)?.pageIdentity == .item(1))
        #expect(restored.pageHistories[tabID] == [.home, .item(1)])
    }

    @Test func prewarmingRebuildsEveryWaitingTab() async {
        let configuration = makeConfiguration()
        let store = TestStore(configuration: configuration)
        let first = store.selectedTabID
        store.setPageIdentity(.home, for: first)
        store.pushPage(1)
        let second = store.openTab()
        store.setPageIdentity(.home, for: second)
        store.pushPage(2)
        await store.flushPersistence()

        let restored = TestStore.restored(configuration: configuration)
        await restored.prewarmRestorablePaths { token, path in
            path.append(token)
            return true
        }
        #expect(restored.tabsAwaitingPathRestore.isEmpty)
        #expect(restored.tab(first)?.path.count == 1)
        #expect(restored.tab(second)?.path.count == 1)
    }

    @Test func visitCountsSurviveARelaunch() {
        let configuration = makeConfiguration()
        let store = TestStore(configuration: configuration)
        store.openTab(at: .settings)

        let restored = TestStore.restored(configuration: configuration)
        #expect(restored.frequentlyVisitedRoots == [.settings])
    }
}

@Suite("Reordering")
struct ReorderingTests {

    @Test func endingAReorderClearsThePlaceholder() {
        let store = makeStore()
        let dragged = store.openTab()
        store.draggedTabID = dragged
        store.reorderingTabID = dragged

        store.endReordering()
        #expect(store.draggedTabID == nil)
        #expect(store.reorderingTabID == nil)
    }

    @Test func leavingTheSwitcherClearsAStrandedPlaceholder() {
        let store = makeStore()
        store.reorderingTabID = store.selectedTabID
        store.hideTabSwitcher()
        #expect(store.reorderingTabID == nil)
        #expect(!store.isShowingTabSwitcher)
    }
}

@Suite("Page slots")
struct PageSlotTests {

    @Test func aSlotOnlyAnswersForThePageThatFilledIt() {
        let slot = PageSlot(token: 1, value: "Share")
        #expect(slot.value(forPageAt: 1) == "Share")
        #expect(slot.value(forPageAt: 2) == nil)
    }

    @Test func aPageOnlyEmptiesItsOwnSlot() {
        var slot: PageSlot<Int, String>?
        PageSlot.fill(&slot, with: "Share", from: 2)
        #expect(slot?.token == 2)

        // A page underneath reporting nothing leaves the visible page's value.
        PageSlot.fill(&slot, with: nil, from: 1)
        #expect(slot?.value == "Share")

        PageSlot.fill(&slot, with: nil, from: 2)
        #expect(slot == nil)
    }
}
