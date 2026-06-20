import SwiftUI

enum ActivityIndicatorGeometry: Equatable {
    case ring
    case circle
    case octagon
}

enum ActivityIndicatorPalette: Equatable {
    case secondary
    case accent
}

struct ActivityIndicatorAppearance: Equatable {
    let geometry: ActivityIndicatorGeometry
    let palette: ActivityIndicatorPalette
    let opacityRange: ClosedRange<Double>
    let blurRadius: CGFloat

    func resolvedOpacity(pulsing: Bool, reduceMotion: Bool) -> Double {
        if reduceMotion { return opacityRange.upperBound }
        return pulsing ? opacityRange.lowerBound : opacityRange.upperBound
    }
}

func activityIndicatorAppearance(for state: PaneActivityState) -> ActivityIndicatorAppearance {
    switch state {
    case .idle:
        ActivityIndicatorAppearance(
            geometry: .ring,
            palette: .secondary,
            opacityRange: 0.4...0.4,
            blurRadius: 0
        )
    case .working:
        ActivityIndicatorAppearance(
            geometry: .circle,
            palette: .secondary,
            opacityRange: 0.55...0.85,
            blurRadius: 1
        )
    case .stopped:
        ActivityIndicatorAppearance(
            geometry: .octagon,
            palette: .secondary,
            opacityRange: 0.5...0.5,
            blurRadius: 0
        )
    case .waiting:
        ActivityIndicatorAppearance(
            geometry: .circle,
            palette: .accent,
            opacityRange: 1...1,
            blurRadius: 0
        )
    }
}

func waitingIndicatorColor(isPriority: Bool) -> Color {
    isPriority ? .orange : Theme.accent
}

struct ActivityIndicatorView: View {
    let state: PaneActivityState
    let enabled: Bool
    let prefix: String
    let name: String
    var isPriority: Bool = false

    var body: some View {
        if enabled {
            indicatorBody
                .frame(width: 7, height: 7)
                .accessibilityIdentifier("\(prefix)-activity-\(stateName)-\(name)")
                .accessibilityLabel("\(prefix) \(stateName) indicator for \(name)")
        }
    }

    private var stateName: String {
        switch state {
        case .idle: "idle"
        case .working: "working"
        case .stopped: "stopped"
        case .waiting: "waiting"
        }
    }

    @ViewBuilder
    private var indicatorBody: some View {
        switch state {
        case .idle:
            Circle()
                .stroke(Color.secondary.opacity(0.4), lineWidth: 1)
        case .working:
            WorkingDot()
        case .stopped:
            StoppedOctagon()
        case .waiting:
            WaitingDot(isPriority: isPriority)
        }
    }
}

private struct WorkingDot: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulsing = false
    private let appearance = activityIndicatorAppearance(for: .working)

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.secondary.opacity(0.35))
                .blur(radius: appearance.blurRadius)
            Circle()
                .fill(Color.secondary.opacity(0.55))
        }
        .opacity(appearance.resolvedOpacity(pulsing: pulsing, reduceMotion: reduceMotion))
        .animation(
            reduceMotion ? .none : .easeInOut(duration: 1.2).repeatForever(autoreverses: true),
            value: pulsing
        )
        .onAppear { pulsing = true }
    }
}

private struct WaitingDot: View {
    let isPriority: Bool
    var body: some View {
        Circle()
            .fill(waitingIndicatorColor(isPriority: isPriority))
    }
}

private struct StoppedOctagon: View {
    var body: some View {
        Image(systemName: "octagon")
            .resizable()
            .scaledToFit()
            .foregroundStyle(Color.secondary.opacity(0.5))
    }
}
