import SwiftUI

enum ActivityIndicatorSymbol: Equatable {
    case idleRing
    case workingDiamond
    case waitingDot
}

func activityIndicatorSymbol(for state: PaneActivityState) -> ActivityIndicatorSymbol {
    switch state {
    case .idle: .idleRing
    case .working: .workingDiamond
    case .waiting: .waitingDot
    }
}

struct ActivityIndicatorView: View {
    let state: PaneActivityState
    let enabled: Bool
    let prefix: String
    let name: String

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
        case .waiting: "waiting"
        }
    }

    @ViewBuilder
    private var indicatorBody: some View {
        switch activityIndicatorSymbol(for: state) {
        case .idleRing:
            Circle()
                .stroke(Color.secondary.opacity(0.4), lineWidth: 1)
        case .workingDiamond:
            WorkingDiamond()
        case .waitingDot:
            WaitingDot()
        }
    }
}

private struct WorkingDiamond: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulsing = false

    var body: some View {
        RoundedRectangle(cornerRadius: 0.75)
            .fill(Color.secondary)
            .frame(width: 5, height: 5)
            .rotationEffect(.degrees(45))
            .opacity(pulsing ? 0.5 : 1.0)
            .animation(
                reduceMotion ? .none : .easeInOut(duration: 1.2).repeatForever(autoreverses: true),
                value: pulsing
            )
            .onAppear { pulsing = true }
    }
}

private struct WaitingDot: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulsing = false

    var body: some View {
        Circle()
            .fill(Color.accentColor)
            .opacity(pulsing ? 0.5 : 1.0)
            .animation(
                reduceMotion ? .none : .easeInOut(duration: 1.2).repeatForever(autoreverses: true),
                value: pulsing
            )
            .onAppear { pulsing = true }
    }
}
