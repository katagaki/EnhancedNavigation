import EnhancedNavigation
import SwiftUI

struct MediaFeaturePage: View {

    @Environment(HarnessMediaCenter.self) private var media

    let identity: HarnessPageIdentity

    var body: some View {
        HarnessPage(identity: identity) {
            HarnessSection("Now Playing") {
                NowPlayingValue()
            }
            HarnessSection(
                "Try It",
                footer: "Playing media survives being covered, switching tabs and eviction, and a tab that is playing is never the one evicted. Popping the player or closing its tab stops it."
            ) {
                NavigationLink("Open Player 1", value: HarnessDestination.player(1))
                    .harnessIdentifier("media.player1")
                NavigationLink("Open Player 2", value: HarnessDestination.player(2))
            }
            FeatureFooter(feature: .media)
        }
    }
}

struct PlayerPage: View {

    @Environment(HarnessStore.self) private var store
    @Environment(HarnessMediaCenter.self) private var media
    @Environment(\.harnessTabID) private var tabID

    let number: Int

    var body: some View {
        HarnessPage(identity: .player(number)) {
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.black)
                    .aspectRatio(16 / 9, contentMode: .fit)
                if let playback, media.owns(playback) {
                    TimelineView(.animation) { context in
                        let phase = context.date.timeIntervalSinceReferenceDate
                        Image(systemName: "waveform")
                            .font(.system(size: 64))
                            .foregroundStyle(.white)
                            .symbolEffect(.variableColor.iterative, isActive: true)
                            .rotationEffect(.degrees(sin(phase) * 4))
                    }
                } else {
                    Image(systemName: "play.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }

            HarnessSection("Playback") {
                NowPlayingValue()
                Button(isPlaying ? "Pause" : "Play", systemImage: isPlaying ? "pause.fill" : "play.fill") {
                    guard let playback else { return }
                    if isPlaying { media.stop() } else { media.play(playback) }
                }
                .harnessIdentifier("player.toggle")
                NavigationLink("Push Item 1 over the player", value: HarnessDestination.item(1))
            }
        }
        .onAppear {
            guard let tabID, let playback else { return }
            store.registerMediaPage(
                .player(number),
                in: tabID,
                ownsMedia: { [media] in media.owns(playback) },
                stop: { [media] in media.stop() }
            )
        }
    }

    private var playback: HarnessMediaCenter.Playback? {
        tabID.map { HarnessMediaCenter.Playback(tabID: $0, number: number) }
    }

    private var isPlaying: Bool {
        playback.map(media.owns) ?? false
    }
}

private struct NowPlayingValue: View {

    @Environment(HarnessMediaCenter.self) private var media

    var body: some View {
        HarnessValue(
            title: "Now playing",
            value: media.nowPlaying.map { "Player \($0.number)" } ?? "Nothing",
            identifier: "media.status"
        )
    }
}
