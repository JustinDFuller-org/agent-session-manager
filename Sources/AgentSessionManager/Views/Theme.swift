import AppKit
import SwiftUI

// Explicit sRGB values matching the macOS 26.4 dark appearance. Pinning these
// in code prevents the macOS 27 SDK design system from remapping semantic colors
// to lighter values when building against a newer SDK.
enum WindowChromeButton: CaseIterable, Hashable {
    case close
    case minimize
    case zoom

    var nsButton: NSWindow.ButtonType {
        switch self {
        case .close: .closeButton
        case .minimize: .miniaturizeButton
        case .zoom: .zoomButton
        }
    }
}

struct WindowChromeConfiguration {
    let backgroundColor: NSColor
    let appearanceName: NSAppearance.Name
    let titleVisibility: NSWindow.TitleVisibility
    let titlebarAppearsTransparent: Bool
    let fullSizeContentView: Bool
    let disabledButtons: Set<WindowChromeButton>
}

enum Theme {
    // rgb(0, 90, 209) — matches the xcode 26 dark system accent
    static let accent = Color(.sRGB, red: 0.0, green: 0.353, blue: 0.820, opacity: 1.0)
    static let mac26WindowChrome = Color(.sRGB, red: 0.106, green: 0.106, blue: 0.106, opacity: 1.0)
    static let mac26Content = Color(.sRGB, red: 0.118, green: 0.118, blue: 0.118, opacity: 1.0)
    static let mac26Sidebar = Color(.sRGB, red: 0.106, green: 0.106, blue: 0.106, opacity: 1.0)
    static let mac26Card = Color(.sRGB, red: 0.125, green: 0.125, blue: 0.125, opacity: 1.0)
    static let mac26Field = Color(.sRGB, red: 0.235, green: 0.235, blue: 0.235, opacity: 1.0)
    static let mac26AltRow = Color(.sRGB, red: 0.149, green: 0.149, blue: 0.149, opacity: 1.0)
    static let mac26SelectedBlue = Color(.sRGB, red: 0.141, green: 0.341, blue: 0.788, opacity: 1.0)

    static let windowBackground = mac26Content
    static let controlBackground = mac26WindowChrome
    static let paneBackground = mac26Content
    static let barBackground = mac26WindowChrome
    static let sidebarBackground = mac26Sidebar
    static let overlayMaterial = Color(.sRGB, red: 0.059, green: 0.059, blue: 0.059, opacity: 0.9)
    static let cardBackground = mac26Card

    static let mainWindowChrome = WindowChromeConfiguration(
        backgroundColor: NSColor(mac26WindowChrome),
        appearanceName: .darkAqua,
        titleVisibility: .hidden,
        titlebarAppearsTransparent: true,
        fullSizeContentView: true,
        disabledButtons: []
    )

    static let settingsWindowChrome = WindowChromeConfiguration(
        backgroundColor: NSColor(mac26WindowChrome),
        appearanceName: .darkAqua,
        titleVisibility: .visible,
        titlebarAppearsTransparent: false,
        fullSizeContentView: false,
        disabledButtons: [.minimize, .zoom]
    )

    static let dashboardWindowChrome = WindowChromeConfiguration(
        backgroundColor: NSColor(mac26WindowChrome),
        appearanceName: .darkAqua,
        titleVisibility: .hidden,
        titlebarAppearsTransparent: false,
        fullSizeContentView: false,
        disabledButtons: []
    )

    @MainActor
    static func configure(window: NSWindow, using configuration: WindowChromeConfiguration) {
        window.appearance = NSAppearance(named: configuration.appearanceName)
        window.backgroundColor = configuration.backgroundColor
        window.titleVisibility = configuration.titleVisibility
        window.titlebarAppearsTransparent = configuration.titlebarAppearsTransparent
        if configuration.fullSizeContentView {
            window.styleMask.insert(.fullSizeContentView)
        } else {
            window.styleMask.remove(.fullSizeContentView)
        }
        for button in WindowChromeButton.allCases {
            guard let standardButton = window.standardWindowButton(button.nsButton) else { continue }
            standardButton.isHidden = false
            standardButton.isEnabled = !configuration.disabledButtons.contains(button)
        }
    }
}

private final class WindowChromeView: NSView {
    var configuration: WindowChromeConfiguration { didSet { applyToWindow() } }

    init(configuration: WindowChromeConfiguration) {
        self.configuration = configuration
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        applyToWindow()
    }

    private func applyToWindow() {
        guard let window else { return }
        Theme.configure(window: window, using: configuration)
    }
}

private struct WindowChromeAccessor: NSViewRepresentable {
    let configuration: WindowChromeConfiguration

    func makeNSView(context: Context) -> WindowChromeView { WindowChromeView(configuration: configuration) }
    func updateNSView(_ view: WindowChromeView, context: Context) { view.configuration = configuration }
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

    func pinnedWindowChrome(_ configuration: WindowChromeConfiguration) -> some View {
        background(WindowChromeAccessor(configuration: configuration))
    }
}
