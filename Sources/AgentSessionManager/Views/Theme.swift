import AppKit
import SwiftUI

// Explicit sRGB values matching the macOS 26.4 dark appearance. Pinning these
// in code prevents the macOS 27 SDK design system from remapping semantic colors
// to lighter values when building against a newer SDK.
enum Theme {
    // rgb(0, 90, 209) — matches the xcode 26 dark system accent
    static let accent = Color(.sRGB, red: 0.0, green: 0.353, blue: 0.820, opacity: 1.0)
    static let windowBackground = Color(.sRGB, red: 0.106, green: 0.106, blue: 0.106, opacity: 1.0)
    static let controlBackground = Color(.sRGB, red: 0.102, green: 0.102, blue: 0.102, opacity: 1.0)
    static let paneBackground = Color(.sRGB, red: 0.0, green: 0.0, blue: 0.0, opacity: 1.0)
    static let barBackground = Color(.sRGB, red: 0.157, green: 0.157, blue: 0.157, opacity: 1.0)
    static let sidebarBackground = Color(.sRGB, red: 0.118, green: 0.118, blue: 0.118, opacity: 1.0)
    static let overlayMaterial = Color(.sRGB, red: 0.059, green: 0.059, blue: 0.059, opacity: 0.9)
    static let cardBackground = Color(.sRGB, red: 0.133, green: 0.133, blue: 0.133, opacity: 1.0)
}

private final class WindowChromeView: NSView {
    var color: NSColor { didSet { applyToWindow() } }

    init(color: NSColor) {
        self.color = color
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        applyToWindow()
    }

    private func applyToWindow() {
        guard let window else { return }
        window.titlebarAppearsTransparent = true
        window.backgroundColor = color
    }
}

private struct WindowChromeAccessor: NSViewRepresentable {
    let color: NSColor

    func makeNSView(context: Context) -> WindowChromeView { WindowChromeView(color: color) }
    func updateNSView(_ view: WindowChromeView, context: Context) { view.color = color }
}

extension View {
    func pinnedFormBackground() -> some View {
        self
            .scrollContentBackground(.hidden)
            .background(Theme.windowBackground)
    }

    func pinnedListRowBackground() -> some View {
        self.listRowBackground(Theme.cardBackground)
    }

    func pinnedSheetBackground() -> some View {
        self.presentationBackground(Theme.windowBackground)
    }

    func pinnedWindowChrome(_ color: Color) -> some View {
        background(WindowChromeAccessor(color: NSColor(color)))
    }
}
