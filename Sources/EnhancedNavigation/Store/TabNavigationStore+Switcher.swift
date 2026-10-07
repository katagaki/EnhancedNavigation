import SwiftUI

public extension TabNavigationStore {

    /// Shows the tab grid from a layout that keeps a visible tab strip.
    func showTabOverview() {
        showTabSwitcher()
    }

    func showTabSwitcher() {
        // Only of a page at rest. Over a growth cut short the window holds the
        // zoom mid-flight, grid bar and all, and that card would then grow
        // back out of it every visit after; a page still growing has had no
        // chance to change since its last snapshot anyway.
        if !isPageClipActive {
            captureSelectedTabSnapshot()
        }
        if !isPageGrowingFromSnapshot {
            // A fade still running is over the live page, which collapses
            // as itself.
            setWithoutAnimation { snapshotStandInTabID = nil }
        }
        freezeCollapseTarget()
        setWithoutAnimation {
            isPageClipActive = true
            isShowingTabSwitcher = true
        }
        withAnimation(configuration.switcherAnimation, completionCriteria: .removed) {
            isPageCollapsed = true
        } completion: {
            // Not if the collapse was reversed while it ran: the completion
            // still fires, and the page is back at full screen by then.
            guard self.isPageCollapsed else { return }
            self.setWithoutAnimation { self.isPageSwappedForSnapshot = true }
        }
    }

    /// The chrome is handed back up front, mirroring the collapse. Waiting for
    /// the page to land leaves the switcher's own navigation bar blurring over
    /// the growing page, and swaps the bars under it at the very end, which
    /// nudges the page's content as it settles.
    func hideTabSwitcher() {
        if !isPageCollapsed {
            endReordering()
            setWithoutAnimation { isShowingTabSwitcher = false }
            return
        }
        freezeCollapseTarget()
        // A drag let go of outside the grid is not reported before iOS 27,
        // so its placeholder would otherwise greet the next visit.
        endReordering()
        setWithoutAnimation {
            isShowingTabSwitcher = false
            // Here rather than with the growth: flipped in the same pass as
            // it, the stand-in is swept into the zoom's animation. A tab
            // opened from the switcher has no snapshot, and grows live.
            snapshotStandInTabID = snapshots[selectedTabID] != nil ? selectedTabID : nil
            isPageGrowingFromSnapshot = snapshotStandInTabID != nil
        }
        // A tick later: the page re-lays itself out around its own bars the
        // moment the chrome comes back, and doing that in the same pass as
        // the swap drops its content by a bar's height in the first frame of
        // the growth. Behind the snapshot it costs nothing.
        Task { @MainActor in
            self.setWithoutAnimation { self.isPageSwappedForSnapshot = false }
            withAnimation(self.configuration.switcherAnimation, completionCriteria: .removed) {
                self.isPageCollapsed = false
            } completion: {
                guard !self.isPageCollapsed, !self.isShowingTabSwitcher else { return }
                self.setWithoutAnimation {
                    self.isPageClipActive = false
                    self.isPageGrowingFromSnapshot = false
                }
                self.fadeOutSnapshotStandIn()
            }
        }
    }

    func setCardFrame(_ frame: CGRect, for tabID: UUID) {
        guard cardFrames[tabID] != frame else { return }
        cardFrames[tabID] = frame
    }
}

extension TabNavigationStore {

    /// Outside the transition: changes flushed in the same cycle are otherwise
    /// swept into it.
    private func setWithoutAnimation(_ change: () -> Void) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction, change)
    }

    /// Not until the live page has drawn behind it: its first frames back
    /// are its heaviest, and a fade over them stutters.
    private func fadeOutSnapshotStandIn() {
        guard let tabID = snapshotStandInTabID else { return }
        Task { @MainActor in
            await FrameClock.waitForSettledFrames()
            guard snapshotStandInTabID == tabID, !isPageGrowingFromSnapshot else { return }
            withAnimation(configuration.snapshotFadeAnimation) {
                snapshotStandInTabID = nil
            }
        }
    }

    private func freezeCollapseTarget() {
        // Cleared, not left alone: a tab opened from the switcher has no frame
        // yet, and a stale one zooms out of the previously selected tab.
        collapseTarget = cardFrames[selectedTabID]
    }
}
