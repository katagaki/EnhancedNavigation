import SwiftUI

/// What a card shows for a tab that has not been left yet, so has no
/// snapshot.
public enum TabSwitcherPlaceholderIcon {
    case systemImage(String)
    case asset(String, bundle: Bundle? = nil)

    var image: Image {
        switch self {
        case .systemImage(let name): Image(systemName: name)
        case .asset(let name, let bundle): Image(name, bundle: bundle)
        }
    }
}

struct TabSwitcherCardPlaceholder: View {

    let icon: TabSwitcherPlaceholderIcon

    var body: some View {
        icon.image
            .resizable()
            .scaledToFit()
            .frame(width: 56)
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
