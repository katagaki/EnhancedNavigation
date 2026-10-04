import EnhancedNavigation
import SwiftUI

@main
struct HarnessApp: App {

    @State private var session = HarnessSession()

    var body: some Scene {
        WindowGroup {
            HarnessShell()
                // A simulated relaunch swaps the store out; a fresh identity
                // tears the old tree down with it, as a real relaunch would.
                .id(session.launchCount)
                .environment(session)
                .environment(session.store)
                .environment(session.media)
        }
        .commands { TabCommands() }
    }
}

/// Owns the store, so the harness can throw it away and read it back from
/// disk without leaving the app.
@Observable
final class HarnessSession {

    /// `-LiveTabLimit <n>` overrides the limit, `-ResetState YES` starts from
    /// nothing, which is what the UI tests launch with.
    static let configuration: TabStoreConfiguration = {
        let limit = UserDefaults.standard.integer(forKey: "LiveTabLimit")
        return TabStoreConfiguration(
            liveTabLimit: limit > 0 ? limit : 3,
            persistenceKeyPrefix: "EnhancedNavigationHarness",
            snapshotDirectoryName: "EnhancedNavigationHarnessSnapshots",
            frequentlyVisitedLimit: 4
        )
    }()

    private(set) var store: HarnessStore
    private(set) var launchCount = 1
    /// What the store has told the app through its callbacks, newest first.
    private(set) var events: [String] = []
    let media = HarnessMediaCenter()

    init() {
        if UserDefaults.standard.bool(forKey: "ResetState") {
            Self.resetPersistedState()
        }
        store = HarnessStore.restored(configuration: Self.configuration)
        observe(store)
    }

    /// Writes the tabs out, drops the store and every view built on it, and
    /// reads the tabs back in the way a cold launch does.
    func relaunch() async {
        // The store coalesces its writes to the next pass.
        for _ in 0..<5 { await Task.yield() }
        media.stop()
        store = HarnessStore.restored(configuration: Self.configuration)
        observe(store)
        launchCount += 1
        log("Relaunched: \(store.tabsAwaitingPathRestore.count) tab(s) awaiting rebuild")
    }

    func log(_ event: String) {
        events.insert(event, at: 0)
        events = Array(events.prefix(20))
    }

    private func observe(_ store: HarnessStore) {
        store.onTabsClosed = { [weak self] closed in
            self?.log("Closed \(closed.count) tab(s)")
        }
    }

    private static func resetPersistedState() {
        let defaults = UserDefaults.standard
        let prefix = configuration.persistenceKeyPrefix
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix(prefix) {
            defaults.removeObject(forKey: key)
        }
        if let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first {
            try? FileManager.default.removeItem(
                at: caches.appending(path: configuration.snapshotDirectoryName)
            )
        }
    }
}

/// Stands in for an audio session: one thing plays at a time.
@Observable
final class HarnessMediaCenter {

    struct Playback: Equatable {
        let tabID: UUID
        let number: Int
    }

    private(set) var nowPlaying: Playback?

    func play(_ playback: Playback) {
        nowPlaying = playback
    }

    func stop() {
        nowPlaying = nil
    }

    func owns(_ playback: Playback) -> Bool {
        nowPlaying == playback
    }
}
