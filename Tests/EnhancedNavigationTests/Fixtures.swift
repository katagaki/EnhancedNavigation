import Foundation
@testable import EnhancedNavigation

nonisolated enum TestRoot: String, TabRoot {
    case home
    case library
    case settings

    static var newTabRoot: TestRoot { .home }

    var persistenceToken: String { rawValue }

    init?(persistenceToken: String) {
        self.init(rawValue: persistenceToken)
    }

    var isRecordedAsVisit: Bool { self != .home }
}

nonisolated struct TestPage: TabPageIdentity {
    var title: String
    var pathToken: Int?

    func names(_ other: TestPage) -> Bool {
        guard let pathToken, let otherToken = other.pathToken else { return title == other.title }
        return pathToken == otherToken
    }

    static let home = TestPage(title: "Home", pathToken: nil)

    static func item(_ number: Int) -> TestPage {
        TestPage(title: "Item \(number)", pathToken: number)
    }
}

typealias TestStore = TabNavigationStore<TestRoot, TestPage>

/// Each store gets keys of its own, so tests never read one another's tabs.
func makeConfiguration(liveTabLimit: Int = 4) -> TabStoreConfiguration {
    let prefix = "EnhancedNavigationTests.\(UUID().uuidString)"
    return TabStoreConfiguration(
        liveTabLimit: liveTabLimit,
        persistenceKeyPrefix: prefix,
        snapshotDirectoryName: prefix
    )
}

func makeStore(liveTabLimit: Int = 4) -> TestStore {
    TestStore(configuration: makeConfiguration(liveTabLimit: liveTabLimit))
}

extension TestStore {
    /// Pushes a page and reports it, the way a page's `onAppear` would.
    func pushPage(_ number: Int) {
        push(number)
        setPageIdentity(.item(number), for: selectedTabID)
    }

    /// Lets the coalesced write run.
    func flushPersistence() async {
        for _ in 0..<5 {
            await Task.yield()
        }
    }
}

/// Stands in for a player: plays until stopped.
final class FakePlayer {
    var isPlaying = true
    private(set) var stopCount = 0

    func stop() {
        isPlaying = false
        stopCount += 1
    }
}
