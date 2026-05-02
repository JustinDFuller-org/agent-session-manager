import SwiftUI

struct NewPaneSheet: View {
    @Environment(\.dismiss) private var dismiss
    let tab: Tab

    @State private var worktreeName = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("New Pane")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                Text("Worktree / Branch Name")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                TextField("auth-refactor, fix-login-bug, etc.", text: $worktreeName)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { create() }
                    .accessibilityIdentifier("new-pane-name-field")
                Text("Will open at \(tab.directory.lastPathComponent)/.tree/\(worktreeName.isEmpty ? "<name>" : worktreeName)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .font(.system(.caption, design: .monospaced))
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                    .accessibilityIdentifier("new-pane-cancel-button")
                Button("Open") { create() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(worktreeName.isEmpty)
                    .accessibilityIdentifier("new-pane-open-button")
            }
        }
        .padding(24)
        .frame(width: 420)
    }

    private func create() {
        guard !worktreeName.isEmpty else { return }
        tab.addPane(name: worktreeName)
        dismiss()
    }
}
