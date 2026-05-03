import SwiftUI

struct StatusLineView: View {
    let monitor: StatusLineMonitor
    let config: StatusLineConfig

    private var visibleItems: [StatusLineItem] {
        config.items.filter(\.isVisible)
    }

    var body: some View {
        if let data = monitor.currentData, !visibleItems.isEmpty {
            HStack(spacing: 0) {
                ForEach(Array(visibleItems.enumerated()), id: \.element.id) { index, item in
                    if index > 0 {
                        Text(" · ")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    Text(text(for: item.id, data: data))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fontDesign(.monospaced)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .windowBackgroundColor))
        }
    }

    private func text(for itemID: String, data: StatusLineData) -> String {
        switch itemID {
        case "model":
            return data.model?.displayName ?? data.model?.id ?? "—"
        case "worktree":
            return data.worktree?.name ?? "—"
        case "cost":
            return String(format: "$%.4f", data.cost?.totalCostUsd ?? 0)
        case "context":
            return "\(data.contextWindow?.usedPercentage ?? 0)% ctx"
        case "effort":
            return data.effort?.level ?? "—"
        case "thinking":
            return data.thinking?.enabled == true ? "thinking on" : "thinking off"
        case "vimMode":
            return data.vim?.mode ?? "—"
        case "agentName":
            return data.agent?.name ?? "—"
        case "sessionName":
            return data.sessionName ?? "—"
        case "worktreeBranch":
            return data.worktree?.branch ?? "—"
        case "gitWorktree":
            return data.workspace?.gitWorktree ?? "—"
        case "linesAdded":
            return "+\(data.cost?.totalLinesAdded ?? 0)"
        case "linesRemoved":
            return "-\(data.cost?.totalLinesRemoved ?? 0)"
        case "duration":
            return formatDuration(ms: data.cost?.totalDurationMs ?? 0)
        case "contextRemaining":
            return "\(data.contextWindow?.remainingPercentage ?? 0)% remaining"
        case "inputTokens":
            return "\(data.contextWindow?.totalInputTokens ?? 0) in"
        case "outputTokens":
            return "\(data.contextWindow?.totalOutputTokens ?? 0) out"
        case "rate5h":
            return String(format: "5h: %.0f%%", data.rateLimits?.fiveHour?.usedPercentage ?? 0)
        case "rate7d":
            return String(format: "7d: %.0f%%", data.rateLimits?.sevenDay?.usedPercentage ?? 0)
        case "rate5hReset":
            if let ts = data.rateLimits?.fiveHour?.resetsAt {
                return "5h resets \(formatResetTime(ts))"
            }
            return "—"
        case "rate7dReset":
            if let ts = data.rateLimits?.sevenDay?.resetsAt {
                return "7d resets \(formatResetTime(ts))"
            }
            return "—"
        case "version":
            return data.version ?? "—"
        case "outputStyle":
            return data.outputStyle?.name ?? "—"
        case "exceeds200k":
            return data.exceeds200kTokens == true ? "⚠ 200k+" : "—"
        default:
            return "—"
        }
    }

    private func formatDuration(ms: Double) -> String {
        let seconds = Int(ms / 1000)
        if seconds < 60 { return "\(seconds)s" }
        let minutes = seconds / 60
        let secs = seconds % 60
        if minutes < 60 { return secs > 0 ? "\(minutes)m \(secs)s" : "\(minutes)m" }
        let hours = minutes / 60
        let mins = minutes % 60
        return mins > 0 ? "\(hours)h \(mins)m" : "\(hours)h"
    }

    private func formatResetTime(_ timestamp: Int) -> String {
        let remaining = TimeInterval(timestamp) - Date().timeIntervalSince1970
        guard remaining > 0 else { return "now" }
        let hours = Int(remaining) / 3600
        let minutes = (Int(remaining) % 3600) / 60
        if hours > 0 { return "in \(hours)h \(minutes)m" }
        return "in \(minutes)m"
    }
}
