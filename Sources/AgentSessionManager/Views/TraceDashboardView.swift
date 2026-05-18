import SwiftUI

struct TraceDashboardView: View {
    @Environment(TraceStore.self) private var store
    @State private var filterText = ""
    @State private var selectedSpan: StoredSpan?

    private var filteredSpans: [StoredSpan] {
        guard !filterText.isEmpty else { return store.spans }
        return store.spans.filter { $0.name.localizedCaseInsensitiveContains(filterText) }
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            if store.spans.isEmpty {
                emptyState
            } else {
                content
            }
        }
        .frame(minWidth: 700, minHeight: 400)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var toolbar: some View {
        HStack(spacing: 8) {
            TextField("Filter spans…", text: $filterText)
                .textFieldStyle(.roundedBorder)
                .frame(width: 220)
                .accessibilityIdentifier("trace-dashboard-filter-field")
            Spacer()
            Text("\(store.spans.count) span\(store.spans.count == 1 ? "" : "s")")
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("trace-dashboard-span-count")
            Button("Clear") {
                store.clear()
                selectedSpan = nil
            }
            .accessibilityIdentifier("trace-dashboard-clear-button")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "waveform.path.ecg")
                .font(.system(size: 36))
                .foregroundStyle(.quaternary)
            Text("No spans captured.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("Enable tracing in Settings → Tracing and use the app.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier("trace-dashboard-empty-state")
    }

    private var content: some View {
        VSplitView {
            TraceWaterfallView(spans: filteredSpans, selectedSpan: $selectedSpan)
                .frame(minHeight: 200)
            if let span = selectedSpan {
                SpanDetailView(span: span)
                    .frame(minHeight: 120, maxHeight: 240)
            }
        }
    }
}

struct TraceWaterfallView: View {
    let spans: [StoredSpan]
    @Binding var selectedSpan: StoredSpan?

    private static let labelWidth: CGFloat = 200
    private static let rowHeight: CGFloat = 20
    private static let rowPadding: CGFloat = 2

    private var windowStart: Int64 { spans.map(\.startEpochMs).min() ?? 0 }
    private var windowEnd: Int64 { spans.map(\.endEpochMs).max() ?? 1 }
    private var windowDuration: Double {
        let d = Double(windowEnd - windowStart)
        return d > 0 ? d : 1
    }

    var body: some View {
        ScrollView([.vertical, .horizontal]) {
            VStack(spacing: 0) {
                timeAxis
                ForEach(Array(spans.enumerated()), id: \.element.id) { index, span in
                    spanRow(span: span, index: index)
                }
            }
            .padding(.bottom, 8)
        }
        .background(Color(nsColor: .textBackgroundColor))
        .accessibilityIdentifier("trace-dashboard-waterfall")
    }

    private var timeAxis: some View {
        GeometryReader { geo in
            let barWidth = max(0, geo.size.width - Self.labelWidth)
            Canvas { ctx, size in
                let ticks = 5
                for i in 0...ticks {
                    let x = Self.labelWidth + (barWidth / CGFloat(ticks)) * CGFloat(i)
                    let ms = Int64(Double(i) / Double(ticks) * windowDuration)
                    let label = "\(ms)ms"
                    let resolved = ctx.resolve(
                        Text(label)
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(Color.secondary)
                    )
                    ctx.draw(resolved, at: CGPoint(x: x, y: size.height / 2), anchor: .center)
                }
            }
        }
        .frame(height: 16)
        .padding(.bottom, 2)
    }

    private func spanRow(span: StoredSpan, index: Int) -> some View {
        let isSelected = selectedSpan?.id == span.id
        return GeometryReader { geo in
            let barWidth = max(0, geo.size.width - Self.labelWidth)
            let startRatio = Double(span.startEpochMs - windowStart) / windowDuration
            let endRatio = Double(span.endEpochMs - windowStart) / windowDuration
            let x = Self.labelWidth + CGFloat(startRatio) * barWidth
            let w = max(4, CGFloat(endRatio - startRatio) * barWidth)

            ZStack(alignment: .leading) {
                if isSelected {
                    Color.accentColor.opacity(0.1)
                } else if index % 2 == 1 {
                    Color(nsColor: .controlBackgroundColor).opacity(0.5)
                }

                HStack(spacing: 0) {
                    Text(span.name)
                        .font(.system(size: 10, weight: .regular, design: .monospaced))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(width: Self.labelWidth, alignment: .leading)
                        .padding(.leading, 8)

                    if span.durationMs == 0 {
                        Circle()
                            .fill(spanColor(for: span.name))
                            .frame(width: 6, height: 6)
                            .offset(x: x - Self.labelWidth - 3)
                    } else {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(spanColor(for: span.name))
                            .frame(width: w, height: Self.rowHeight - Self.rowPadding * 2 - 2)
                            .offset(x: x - Self.labelWidth)
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
        .frame(height: Self.rowHeight)
    }

    private func spanColor(for name: String) -> Color {
        let prefix = name.components(separatedBy: ".").first ?? name
        switch prefix {
        case "terminal": return .accentColor
        case "pane": return .blue
        case "tab": return .green
        case "pr": return .orange
        case "statusline": return .purple
        default: return .gray
        }
    }
}

struct SpanDetailView: View {
    let span: StoredSpan

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .medium
        return f
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
        .background(Color(nsColor: .controlBackgroundColor))
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
