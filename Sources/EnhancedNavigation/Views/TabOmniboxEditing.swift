import SwiftUI

struct TabOmniboxEditor {
    let isEditing: Binding<Bool>
    let field: () -> AnyView
}

struct TabOmniboxPopup {
    let isPresented: Bool
    let maxHeight: CGFloat
    let content: () -> AnyView
}

private struct TabOmniboxEditorKey: EnvironmentKey {
    static let defaultValue: TabOmniboxEditor? = nil
}

private struct TabOmniboxPopupKey: EnvironmentKey {
    static let defaultValue: TabOmniboxPopup? = nil
}

extension EnvironmentValues {
    var tabOmniboxEditor: TabOmniboxEditor? {
        get { self[TabOmniboxEditorKey.self] }
        set { self[TabOmniboxEditorKey.self] = newValue }
    }

    var tabOmniboxPopup: TabOmniboxPopup? {
        get { self[TabOmniboxPopupKey.self] }
        set { self[TabOmniboxPopupKey.self] = newValue }
    }
}

/// Where the wide layout's omnibox sits, so its popup can be drawn above the
/// page rather than inside the toolbar's glass, which only hit-tests within
/// its own bounds.
struct TabOmniboxBoundsKey: PreferenceKey {
    static let defaultValue: Anchor<CGRect>? = nil

    static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
        value = nextValue() ?? value
    }
}

public extension View {

    /// Makes the omnibox in `AdaptiveTabContainer`'s wide layout editable.
    /// Tapping it, or pressing Command-L, sets `isEditing`; while it is true
    /// `field` takes the tab label's place, and Escape, switching tabs, or
    /// tapping the page sets it back. Has no effect on the iPhone layout,
    /// whose omnibox lives in the app's own bottom bar.
    func tabOmniboxEditing<Field: View>(
        isEditing: Binding<Bool>,
        @ViewBuilder field: @escaping () -> Field
    ) -> some View {
        environment(
            \.tabOmniboxEditor,
            TabOmniboxEditor(isEditing: isEditing, field: { AnyView(field()) })
        )
    }

    /// A Safari-style panel hung beneath the editing omnibox, shown while
    /// `isPresented` is also true. The panel is at least as wide as the
    /// omnibox and grows with `content` up to `maxHeight` or the room above
    /// the keyboard, whichever is less; give it content that hugs its height,
    /// scrolling once it no longer fits.
    func tabOmniboxPopup<Popup: View>(
        isPresented: Bool = true,
        maxHeight: CGFloat = 480,
        @ViewBuilder content: @escaping () -> Popup
    ) -> some View {
        environment(
            \.tabOmniboxPopup,
            TabOmniboxPopup(
                isPresented: isPresented,
                maxHeight: maxHeight,
                content: { AnyView(content()) }
            )
        )
    }
}

/// The popup, placed beneath the omnibox's anchor.
struct TabOmniboxPopupLayer: View {

    let anchor: Anchor<CGRect>?
    let popup: TabOmniboxPopup

    private let gap: CGFloat = 8
    private let margin: CGFloat = 16
    private let minimumWidth: CGFloat = 420
    private let cornerRadius: CGFloat = 20

    var body: some View {
        GeometryReader { proxy in
            if let anchor {
                let field = proxy[anchor]
                let width = min(
                    max(field.width, minimumWidth),
                    proxy.size.width - margin * 2
                )
                let leading = min(
                    max(field.midX - width / 2, margin),
                    proxy.size.width - margin - width
                )
                let top = field.maxY + gap
                let height = max(
                    0,
                    min(popup.maxHeight, proxy.size.height - proxy.safeAreaInsets.bottom - top - margin)
                )
                panel
                    .frame(width: width)
                    // Proposed the full height so the content can hug it; the
                    // frame itself draws nothing, so taps below fall through.
                    .frame(width: width, height: height, alignment: .top)
                    .offset(x: leading, y: top)
            }
        }
        .ignoresSafeArea()
    }

    private var panel: some View {
        popup.content()
            .frame(maxWidth: .infinity)
            .background(.regularMaterial, in: .rect(cornerRadius: cornerRadius))
            .clipShape(.rect(cornerRadius: cornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(.separator.opacity(0.4), lineWidth: 0.5)
            }
            .shadow(color: .black.opacity(0.15), radius: 20, y: 8)
            .accessibilityIdentifier("adaptive.omnibox.popup")
    }
}
