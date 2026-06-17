import SwiftUI

// Explicit sRGB values matching the macOS 26.4 dark appearance. Pinning these
// in code prevents the macOS 27 SDK design system from remapping semantic colors
// to lighter values when building against a newer SDK.
enum Theme {
    static let windowBackground = Color(.sRGB, red: 0.118, green: 0.118, blue: 0.118, opacity: 1.0)
    static let controlBackground = Color(.sRGB, red: 0.102, green: 0.102, blue: 0.102, opacity: 1.0)
    static let paneBackground = Color(.sRGB, red: 0.0, green: 0.0, blue: 0.0, opacity: 1.0)
    static let barBackground = Color(.sRGB, red: 0.157, green: 0.157, blue: 0.157, opacity: 1.0)
    static let sidebarBackground = Color(.sRGB, red: 0.118, green: 0.118, blue: 0.118, opacity: 1.0)
    static let overlayMaterial = Color(.sRGB, red: 0.059, green: 0.059, blue: 0.059, opacity: 0.9)
    static let cardBackground = Color(.sRGB, red: 0.133, green: 0.133, blue: 0.133, opacity: 1.0)
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
}
