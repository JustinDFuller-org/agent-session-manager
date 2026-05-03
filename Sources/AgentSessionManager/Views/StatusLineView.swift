import SwiftUI

struct StatusLineView: View {
    let monitor: StatusLineMonitor
    let config: StatusLineConfig

    private var visibleItems: [StatusLineItem] {
        config.items.filter(\.isVisible)
    }

    private var row1Items: [StatusLineItem] {
        let n = visibleItems.count
        guard n > 0 else { return [] }
        let count = n <= 4 ? n : (n + 1) / 2
        return Array(visibleItems.prefix(count))
    }

    private var row2Items: [StatusLineItem] {
        guard visibleItems.count >= 5 else { return [] }
        let row1Count = (visibleItems.count + 1) / 2
        return Array(visibleItems.dropFirst(row1Count))
    }

    var body: some View {
        if let data = monitor.currentData, !visibleItems.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                chipRow(items: row1Items, data: data)
                if !row2Items.isEmpty {
                    chipRow(items: row2Items, data: data)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .windowBackgroundColor))
        }
    }

    @ViewBuilder
    private func chipRow(items: [StatusLineItem], data: StatusLineData) -> some View {
        switch config.rowAlignment {
        case .leading:
            HStack(spacing: 12) {
                ForEach(items) { item in
                    chipView(item: item, data: data)
                }
                Spacer(minLength: 0)
            }
        case .spaceBetween:
            HStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    chipView(item: item, data: data)
                    if index < items.count - 1 {
                        Spacer()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func chipView(item: StatusLineItem, data: StatusLineData) -> some View {
        HStack(spacing: 4) {
            if config.chipLabelStyle != .labelOnly {
                Image(systemName: item.sfSymbol)
                    .font(.system(size: 10))
                    .foregroundStyle(item.id == "exceeds200k" && data.exceeds200kTokens == true ? AnyShapeStyle(.orange) : AnyShapeStyle(.tertiary))
            }
            if config.chipLabelStyle == .symbolAndLabel || config.chipLabelStyle == .labelOnly {
                Text(item.label)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            chipContent(for: item.id, data: data)
        }
    }

    @ViewBuilder
    private func chipContent(for itemID: String, data: StatusLineData) -> some View {
        switch itemID {
        case "context":
            let pct = data.contextWindow?.usedPercentage ?? 0
            HStack(spacing: 4) {
                ProgressView(value: Double(pct), total: 100)
                    .progressViewStyle(.linear)
                    .frame(width: 44)
                    .tint(progressTint(pct))
                Text("\(pct)%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        case "rate5h":
            let pct = data.rateLimits?.fiveHour?.usedPercentage ?? 0
            HStack(spacing: 4) {
                ProgressView(value: pct, total: 100)
                    .progressViewStyle(.linear)
                    .frame(width: 32)
                    .tint(progressTint(Int(pct)))
                Text(String(format: "%.0f%%", pct))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        case "rate7d":
            let pct = data.rateLimits?.sevenDay?.usedPercentage ?? 0
            HStack(spacing: 4) {
                ProgressView(value: pct, total: 100)
                    .progressViewStyle(.linear)
                    .frame(width: 32)
                    .tint(progressTint(Int(pct)))
                Text(String(format: "%.0f%%", pct))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        case "exceeds200k":
            Text(data.exceeds200kTokens == true ? "200k+" : "—")
                .font(.caption)
                .foregroundStyle(data.exceeds200kTokens == true ? AnyShapeStyle(.orange) : AnyShapeStyle(.secondary))
        default:
            Text(textValue(for: itemID, data: data))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func progressTint(_ pct: Int) -> Color {
        pct < 70 ? .green : pct < 90 ? .orange : .red
    }

    private func textValue(for itemID: String, data: StatusLineData) -> String {
        switch itemID {
        case "model":
            return data.model?.displayName ?? data.model?.id ?? "—"
        case "worktree":
            return data.worktree?.name ?? "—"
        case "cost":
            return String(format: "$%.4f", data.cost?.totalCostUsd ?? 0)
        case "effort":
            return data.effort?.level ?? "—"
        case "thinking":
            return data.thinking?.enabled == true ? "on" : "off"
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
            return "\(data.contextWindow?.remainingPercentage ?? 0)%"
        case "inputTokens":
            return "\(data.contextWindow?.totalInputTokens ?? 0)"
        case "outputTokens":
            return "\(data.contextWindow?.totalOutputTokens ?? 0)"
        case "rate5hReset":
            if let ts = data.rateLimits?.fiveHour?.resetsAt {
                return formatResetTime(ts)
            }
            return "—"
        case "rate7dReset":
            if let ts = data.rateLimits?.sevenDay?.resetsAt {
                return formatResetTime(ts)
            }
            return "—"
        case "version":
            return data.version ?? "—"
        case "outputStyle":
            return data.outputStyle?.name ?? "—"
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
