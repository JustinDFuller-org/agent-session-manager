import SwiftUI

// MARK: - Data helpers

struct SpanRow {
    let span: StoredSpan
    let depth: Int
}

func buildWaterfallRows(from spans: [StoredSpan]) -> [SpanRow] {
    var spanById: [String: StoredSpan] = [:]
    var childrenByParent: [String: [StoredSpan]] = [:]

    for span in spans { spanById[span.spanId] = span }

    for span in spans {
        if let parentId = span.parentSpanId, spanById[parentId] != nil {
            childrenByParent[parentId, default: []].append(span)
        }
    }

    for key in childrenByParent.keys {
        childrenByParent[key]?.sort { $0.startEpochMs < $1.startEpochMs }
    }

    let roots =
        spans
        .filter { span in
            guard let parentId = span.parentSpanId else { return true }
            return spanById[parentId] == nil
        }
        .sorted { $0.startEpochMs < $1.startEpochMs }

    var result: [SpanRow] = []

    func dfs(_ span: StoredSpan, depth: Int) {
        result.append(SpanRow(span: span, depth: depth))
        for child in childrenByParent[span.spanId] ?? [] {
            dfs(child, depth: depth + 1)
        }
    }

    for root in roots { dfs(root, depth: 0) }
    return result
}

/// Summary of a single trace, derived from its spans.
struct TraceSummary: Identifiable {
    let traceId: String
    let rootName: String
    let startEpochMs: Int64
    let durationMs: Int64
    let spanCount: Int

    var id: String { traceId }
}

func buildTraceSummaries(from spans: [StoredSpan]) -> [TraceSummary] {
    var byTrace: [String: [StoredSpan]] = [:]
    for span in spans { byTrace[span.traceId, default: []].append(span) }

    return byTrace.map { traceId, traceSpans in
        let spanById = Dictionary(uniqueKeysWithValues: traceSpans.map { ($0.spanId, $0) })
        let root =
            traceSpans
            .filter { span in
                guard let pid = span.parentSpanId else { return true }
                return spanById[pid] == nil
            }
            .min(by: { $0.startEpochMs < $1.startEpochMs })
        let start = traceSpans.map(\.startEpochMs).min() ?? 0
        let end = traceSpans.map(\.endEpochMs).max() ?? start
        return TraceSummary(
            traceId: traceId,
            rootName: root?.name ?? traceSpans[0].name,
            startEpochMs: start,
            durationMs: end - start,
            spanCount: traceSpans.count
        )
    }
    .sorted { $0.startEpochMs > $1.startEpochMs }
}

// MARK: - Root dashboard view

struct TraceDashboardView: View {
    @State private var repository: TraceRepository
    @State private var selectedPaneID: String?

    init(tracesDirectory: URL) {
        _repository = State(initialValue: TraceRepository(tracesDirectory: tracesDirectory))
    }

    var body: some View {
        NavigationSplitView {
            TracePaneSidebarView(
                repository: repository,
                selectedPaneID: $selectedPaneID,
                onSelectPane: { pane in
                    selectedPaneID = pane.id
                    repository.selectPane(pane.fileURL)
                }
            )
            .navigationSplitViewColumnWidth(min: 200, ideal: 220)
        } detail: {
            if repository.selectedPaneURL != nil {
                TracePaneDetailView(
                    spans: repository.selectedPaneSpans
                )
            } else {
                traceEmptyDetail
            }
        }
        .frame(minWidth: 700, minHeight: 400)
        .background(Theme.windowBackground)
        .task {
            repository.refresh()
        }
    }

    private var traceEmptyDetail: some View {
        VStack(spacing: 10) {
            Image(systemName: "waveform.path.ecg")
                .font(.system(size: 36))
                .foregroundStyle(.quaternary)
            Text("Select a pane to view its spans.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier("trace-dashboard-empty-detail")
    }
}

// MARK: - Sidebar: tab → pane tree

struct TracePaneSidebarView: View {
    let repository: TraceRepository
    @Binding var selectedPaneID: String?
    let onSelectPane: (TracePane) -> Void

    var body: some View {
        VStack(spacing: 0) {
            sidebarToolbar
            Divider()
            if repository.tabs.isEmpty {
                sidebarEmptyState
            } else {
                sidebarList
            }
        }
    }

    private var sidebarToolbar: some View {
        HStack {
            Text("Panes")
                .font(.headline)
                .foregroundStyle(.primary)
            Spacer()
            Button {
                repository.refresh()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 12))
            }
            .buttonStyle(.borderless)
            .help("Refresh pane list")
            .accessibilityIdentifier("trace-dashboard-refresh-button")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var sidebarEmptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "tray")
                .font(.system(size: 28))
                .foregroundStyle(.quaternary)
            Text("No trace files found.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("Enable tracing with File output and use the app.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier("trace-dashboard-sidebar-empty-state")
    }

    private var sidebarList: some View {
        List(selection: $selectedPaneID) {
            ForEach(repository.tabs) { tab in
                Section(tab.name) {
                    ForEach(tab.panes) { pane in
                        Text(pane.name)
                            .font(.system(size: 12, design: .monospaced))
                            .tag(pane.id)
                            .accessibilityIdentifier("trace-dashboard-pane-row")
                            .onTapGesture { onSelectPane(pane) }
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .background(Theme.sidebarBackground)
        .accessibilityIdentifier("trace-dashboard-sidebar-list")
    }
}

// MARK: - Detail: spans for a selected pane

struct TracePaneDetailView: View {
    let spans: [StoredSpan]
    @State private var selectedTraceId: String?
    @State private var filterText = ""

    private var summaries: [TraceSummary] {
        let all = buildTraceSummaries(from: spans)
        guard !filterText.isEmpty else { return all }
        return all.filter { $0.rootName.localizedCaseInsensitiveContains(filterText) }
    }

    var body: some View {
        VStack(spacing: 0) {
            if let traceId = selectedTraceId {
                let traceSpans = spans.filter { $0.traceId == traceId }
                TraceDetailView(
                    summary: summaries.first { $0.traceId == traceId }
                        ?? TraceSummary(
                            traceId: traceId, rootName: traceId, startEpochMs: 0, durationMs: 0, spanCount: 0),
                    spans: traceSpans,
                    onBack: { selectedTraceId = nil }
                )
            } else {
                TraceListView(
                    summaries: summaries,
                    filterText: $filterText,
                    totalSpanCount: spans.count,
                    onSelect: { selectedTraceId = $0 }
                )
            }
        }
    }
}

// MARK: - Trace list

struct TraceListView: View {
    let summaries: [TraceSummary]
    @Binding var filterText: String
    let totalSpanCount: Int
    let onSelect: (String) -> Void

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            if summaries.isEmpty {
                emptyState
            } else {
                list
            }
        }
    }

    private var toolbar: some View {
        HStack(spacing: 8) {
            TextField("Filter traces…", text: $filterText)
                .textFieldStyle(.roundedBorder)
                .frame(width: 220)
                .accessibilityIdentifier("trace-dashboard-filter-field")
            Spacer()
            Text("\(totalSpanCount) span\(totalSpanCount == 1 ? "" : "s")")
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("trace-dashboard-span-count")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Theme.controlBackground)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "waveform.path.ecg")
                .font(.system(size: 36))
                .foregroundStyle(.quaternary)
            Text("No spans in this pane's file.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier("trace-dashboard-empty-state")
    }

    private var list: some View {
        ScrollView(.vertical) {
            VStack(spacing: 0) {
                listHeader
                Divider()
                ForEach(Array(summaries.enumerated()), id: \.element.id) { index, summary in
                    TraceListRow(summary: summary, rowIndex: index)
                        .contentShape(Rectangle())
                        .onTapGesture { onSelect(summary.traceId) }
                        .accessibilityIdentifier("trace-dashboard-list-row")
                    Divider().padding(.leading, 16)
                }
            }
        }
        .background(Theme.paneBackground)
        .accessibilityIdentifier("trace-dashboard-list")
    }

    private var listHeader: some View {
        HStack(spacing: 0) {
            Text("NAME")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("SPANS")
                .frame(width: 60, alignment: .trailing)
            Text("DURATION")
                .frame(width: 90, alignment: .trailing)
            Text("TIME")
                .frame(width: 90, alignment: .trailing)
        }
        .font(.system(size: 10, weight: .semibold, design: .monospaced))
        .foregroundStyle(.tertiary)
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(Theme.controlBackground)
    }
}

struct TraceListRow: View {
    let summary: TraceSummary
    let rowIndex: Int

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .medium
        return formatter
    }()

    var body: some View {
        HStack(spacing: 0) {
            Text(summary.rootName)
                .font(.system(size: 11, weight: .regular, design: .monospaced))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("\(summary.spanCount)")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 60, alignment: .trailing)

            Text(durationLabel(summary.durationMs))
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 90, alignment: .trailing)

            Text(Self.timeFormatter.string(from: Date(timeIntervalSince1970: Double(summary.startEpochMs) / 1000)))
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.tertiary)
                .frame(width: 90, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(rowIndex % 2 == 1 ? Theme.controlBackground.opacity(0.5) : Color.clear)
    }

    private func durationLabel(_ ms: Int64) -> String {
        if ms == 0 { return "—" }
        return ms < 1000 ? "\(ms)ms" : String(format: "%.2fs", Double(ms) / 1000)
    }
}

// MARK: - Trace detail (single-trace waterfall)

struct TraceDetailView: View {
    let summary: TraceSummary
    let spans: [StoredSpan]
    let onBack: () -> Void
    @State private var selectedSpan: StoredSpan?

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            VSplitView {
                TraceWaterfallView(spans: spans, selectedSpan: $selectedSpan)
                    .frame(minHeight: 200)
                if let span = selectedSpan {
                    SpanDetailView(span: span)
                        .frame(minHeight: 120, maxHeight: 240)
                }
            }
        }
    }

    private var toolbar: some View {
        HStack(spacing: 8) {
            Button(action: onBack) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 11, weight: .semibold))
                    Text("Traces")
                        .font(.system(size: 12))
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.accentColor)
            .accessibilityIdentifier("trace-detail-back-button")

            Divider().frame(height: 14)

            Text(summary.rootName)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(.primary)
                .lineLimit(1)

            Spacer()

            Text("\(summary.spanCount) span\(summary.spanCount == 1 ? "" : "s")")
                .font(.caption)
                .foregroundStyle(.secondary)

            if summary.durationMs > 0 {
                Text(durationLabel(summary.durationMs))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Theme.controlBackground)
    }

    private func durationLabel(_ ms: Int64) -> String {
        ms < 1000 ? "\(ms)ms" : String(format: "%.2fs", Double(ms) / 1000)
    }
}

// MARK: - Single-trace waterfall

struct TraceWaterfallView: View {
    let spans: [StoredSpan]
    @Binding var selectedSpan: StoredSpan?

    private static let labelWidth: CGFloat = 200
    private static let minBarAreaWidth: CGFloat = 500
    private static let rowHeight: CGFloat = 20
    private static let rowPadding: CGFloat = 2
    private static let indentPerDepth: CGFloat = 12

    private var windowStart: Int64 { spans.map(\.startEpochMs).min() ?? 0 }
    private var windowEnd: Int64 { spans.map(\.endEpochMs).max() ?? 1 }
    private var windowDuration: Double {
        let duration = Double(windowEnd - windowStart)
        return duration > 0 ? duration : 1
    }

    var body: some View {
        GeometryReader { geo in
            let totalWidth = max(geo.size.width, Self.labelWidth + Self.minBarAreaWidth)
            let barAreaWidth = totalWidth - Self.labelWidth
            let rows = buildWaterfallRows(from: spans)
            ScrollView([.vertical, .horizontal]) {
                VStack(spacing: 0) {
                    Canvas { ctx, size in
                        let ticks = 5
                        for i in 0...ticks {
                            let x = Self.labelWidth + (barAreaWidth / CGFloat(ticks)) * CGFloat(i)
                            let ms = Int64(Double(i) / Double(ticks) * windowDuration)
                            let label = ms < 1000 ? "\(ms)ms" : String(format: "%.1fs", Double(ms) / 1000)
                            let resolved = ctx.resolve(
                                Text(label)
                                    .font(.system(size: 9, design: .monospaced))
                                    .foregroundStyle(Color.secondary)
                            )
                            ctx.draw(resolved, at: CGPoint(x: x, y: size.height / 2), anchor: .center)
                        }
                    }
                    .frame(height: 16)
                    .padding(.bottom, 2)
                    ForEach(Array(rows.enumerated()), id: \.element.span.id) { index, row in
                        let span = row.span
                        let indent = CGFloat(row.depth) * Self.indentPerDepth
                        let isSelected = selectedSpan?.id == span.id
                        let startRatio = Double(span.startEpochMs - windowStart) / windowDuration
                        let endRatio = Double(span.endEpochMs - windowStart) / windowDuration
                        let barX = CGFloat(startRatio) * barAreaWidth
                        let barW = max(4, CGFloat(endRatio - startRatio) * barAreaWidth)
                        ZStack(alignment: .leading) {
                            if isSelected {
                                Color.accentColor.opacity(0.1)
                            } else if index % 2 == 1 {
                                Theme.controlBackground.opacity(0.5)
                            }

                            HStack(spacing: 0) {
                                Text(span.name)
                                    .font(.system(size: 10, weight: .regular, design: .monospaced))
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                    .padding(.leading, 8 + indent)
                                    .frame(width: Self.labelWidth, alignment: .leading)

                                if span.durationMs == 0 {
                                    Circle()
                                        .fill(spanColor(for: span.name))
                                        .frame(width: 6, height: 6)
                                        .offset(x: barX - 3)
                                } else {
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(spanColor(for: span.name))
                                        .frame(width: barW, height: Self.rowHeight - Self.rowPadding * 2 - 2)
                                        .offset(x: barX)
                                    Text(durationLabel(span.durationMs))
                                        .font(.system(size: 9, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                        .offset(x: barX + barW + 4)
                                }
                                Spacer()
                            }
                        }
                        .frame(height: Self.rowHeight)
                        .contentShape(Rectangle())
                        .onTapGesture { selectedSpan = span }
                        .overlay(
                            isSelected
                                ? RoundedRectangle(cornerRadius: 0)
                                    .stroke(Color.accentColor.opacity(0.4), lineWidth: 1)
                                : nil
                        )
                    }
                }
                .frame(width: totalWidth)
                .padding(.bottom, 8)
            }
            .contentMargins(.horizontal, 16, for: .scrollContent)
        }
        .background(Theme.paneBackground)
        .accessibilityIdentifier("trace-dashboard-waterfall")
    }

    private func durationLabel(_ ms: Int64) -> String {
        ms < 1000 ? "\(ms)ms" : String(format: "%.1fs", Double(ms) / 1000)
    }

    private func spanColor(for name: String) -> Color {
        let prefix = name.components(separatedBy: ".").first ?? name
        switch prefix {
        case "terminal": return .accentColor
        case "pane": return .blue
        case "tab": return .green
        case "pr": return .orange
        case "statusline": return .purple
        case "session": return .teal
        default: return .gray
        }
    }
}

// MARK: - Span detail panel

struct SpanDetailView: View {
    let span: StoredSpan

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .medium
        return formatter
    }()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 16) {
                    labeledValue("Name", span.name)
                    labeledValue("Duration", "\(span.durationMs)ms")
                    labeledValue(
                        "Start",
                        Self.dateFormatter.string(
                            from: Date(timeIntervalSince1970: Double(span.startEpochMs) / 1000)
                        )
                    )
                }

                HStack(spacing: 16) {
                    labeledValue("TraceID", span.traceId)
                    labeledValue("SpanID", span.spanId)
                }

                if !span.attributes.isEmpty {
                    Divider()
                    Text("Attributes")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    ForEach(span.attributes.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                        HStack(alignment: .top, spacing: 8) {
                            Text(key)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .frame(width: 180, alignment: .leading)
                            Text(value)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.primary)
                                .textSelection(.enabled)
                        }
                    }
                }
            }
            .padding(12)
        }
        .background(Theme.controlBackground)
        .accessibilityIdentifier("trace-dashboard-detail-panel")
    }

    private func labeledValue(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .textCase(.uppercase)
            Text(value)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.primary)
                .textSelection(.enabled)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }
}
