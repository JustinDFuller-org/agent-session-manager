import SwiftUI

extension PullRequest {
    var circleColor: Color {
        switch state.lowercased() {
        case "merged": return .purple
        case "closed": return .gray
        default: break
        }
        if hasMergeConflicts { return .red }
        switch buildStatus {
        case .success: return .green
        case .running: return .yellow
        case .failed: return .red
        case .cancelled: return .gray
        case .unknown: return .secondary
        }
    }
}
