import SwiftUI

struct InvariantDashboardView: View {
    @State private var repository: InvariantRepository
    @State private var selectedID: InvariantViolation.ID?
    @State private var filter = ""

    init(directory: URL) {
        _repository = State(initialValue: InvariantRepository(directory: directory))
    }

    private var filteredViolations: [InvariantViolation] {
        guard !filter.isEmpty else { return repository.violations }
        return repository.violations.filter {
            $0.invariantID.localizedCaseInsensitiveContains(filter)
                || $0.integration.localizedCaseInsensitiveContains(filter)
                || $0.description.localizedCaseInsensitiveContains(filter)
        }
    }

    private var selectedViolation: InvariantViolation? {
        repository.violations.first { $0.id == selectedID }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Invariant Dashboard")
                    .font(.system(size: 20, weight: .bold))
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 14)
            .padding(.bottom, 12)
            .background(Theme.mac26WindowChrome)

            HStack(spacing: 8) {
                TextField("Filter violations...", text: $filter)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 240)
                    .accessibilityIdentifier("invariant-dashboard-filter-field")
                Spacer()
                Button {
                    repository.refresh()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .accessibilityIdentifier("invariant-dashboard-refresh-button")
            }
            .padding(12)
            .background(Theme.mac26WindowChrome)

            if let writerError = repository.writerError {
                Text("Invariant log write failed: \(writerError)")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            invariantTable

            Divider()
            contextPanel
        }
        .frame(minWidth: 900, minHeight: 600)
        .background(Theme.mac26Content)
        .task { repository.start() }
        .onReceive(NotificationCenter.default.publisher(for: .invariantReporterDidChange)) { _ in
            repository.start()
        }
    }

    private var invariantTable: some View {
        GeometryReader { geometry in
            let width = max(geometry.size.width, 900)
            let fixedWidth: CGFloat = 120 + 180 + 140 + 300
            let descriptionWidth = max(200, width - fixedWidth - 48)

            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    headerCell("Time", width: 120)
                    headerCell("Integration", width: 180)
                    headerCell("Severity", width: 140)
                    headerCell("ID", width: 300)
                    headerCell("Description", width: descriptionWidth)
                }
                .background(Theme.mac26Sidebar)

                Divider()

                if filteredViolations.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 36))
                            .foregroundStyle(.quaternary)
                        Text("No invariant violations recorded.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(filteredViolations.enumerated()), id: \.element.id) { index, violation in
                                InvariantRow(
                                    violation: violation,
                                    descriptionWidth: descriptionWidth,
                                    isSelected: selectedID == violation.id,
                                    rowIndex: index,
                                    onSelect: { selectedID = violation.id }
                                )
                            }
                        }
                    }
                }
            }
            .accessibilityIdentifier("invariant-dashboard-table")
        }
    }

    private func headerCell(_ title: String, width: CGFloat) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .frame(width: width, height: 40, alignment: .leading)
            .padding(.leading, 16)
    }

    @ViewBuilder
    private var contextPanel: some View {
        if let violation = selectedViolation {
            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Context").font(.headline)
                    ForEach(violation.context.keys.sorted(), id: \.self) { key in
                        Text("\(key)=\(violation.context[key] ?? "")")
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 130)
        } else {
            Text("Select a violation to inspect its context.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(height: 60)
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier("invariant-dashboard-empty-detail")
        }
    }
}

private struct InvariantRow: View {
    let violation: InvariantViolation
    let descriptionWidth: CGFloat
    let isSelected: Bool
    let rowIndex: Int
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 0) {
                Text(violation.timestamp, style: .time)
                    .frame(width: 120, alignment: .leading)
                    .padding(.leading, 16)
                Text(violation.integration)
                    .frame(width: 180, alignment: .leading)
                    .padding(.leading, 16)
                Text(violation.severity.rawValue.capitalized)
                    .frame(width: 140, alignment: .leading)
                    .padding(.leading, 16)
                Text(violation.invariantID)
                    .frame(width: 300, alignment: .leading)
                    .padding(.leading, 16)
                Text(violation.description)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(width: descriptionWidth, alignment: .leading)
                    .padding(.leading, 16)
            }
            .frame(maxWidth: .infinity, minHeight: 36, maxHeight: 36, alignment: .leading)
            .background(rowBackground)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("invariant-dashboard-row")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var rowBackground: some View {
        Group {
            if isSelected {
                Theme.mac26SelectedBlue.opacity(0.2)
            } else if rowIndex.isMultiple(of: 2) {
                Theme.mac26Sidebar
            } else {
                Theme.mac26AltRow
            }
        }
    }
}
