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
            .background(Color(nsColor: .controlBackgroundColor))

            if let writerError = repository.writerError {
                Text("Invariant log write failed: \(writerError)")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Table(filteredViolations, selection: $selectedID) {
                TableColumn("Time") { violation in
                    Text(violation.timestamp, style: .time)
                }
                .width(min: 80, ideal: 100)
                TableColumn("Integration", value: \.integration)
                    .width(min: 100, ideal: 120)
                TableColumn("Severity") { violation in
                    Text(violation.severity.rawValue.capitalized)
                }
                .width(min: 70, ideal: 80)
                TableColumn("ID", value: \.invariantID)
                    .width(min: 160, ideal: 200)
                TableColumn("Description", value: \.description)
            }
            .accessibilityIdentifier("invariant-dashboard-table")

            Divider()
            contextPanel
        }
        .frame(minWidth: 760, minHeight: 440)
        .background(Color(nsColor: .windowBackgroundColor))
        .task { repository.start() }
        .onReceive(NotificationCenter.default.publisher(for: .invariantReporterDidChange)) { _ in
            repository.start()
        }
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
