import SwiftUI

struct NewTabSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var directoryPath = ""

    private var directory: URL? {
        let trimmed = directoryPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return URL(fileURLWithPath: (trimmed as NSString).expandingTildeInPath)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("New Tab")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                Text("Name")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                TextField("Feature Work, Ops, etc.", text: $name)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("new-tab-name-field")
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Directory")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                HStack {
                    TextField("/path/to/repo", text: $directoryPath)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                        .accessibilityIdentifier("new-tab-directory-field")
                    Button("Choose…") { pickDirectory() }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("new-tab-choose-dir-button")
                }
            }

            if name.isEmpty || directory == nil {
                Text("Both a name and directory are required.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("new-tab-required-hint")
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                    .accessibilityIdentifier("new-tab-cancel-button")
                Button("Create") {
                    if let dir = directory, !name.isEmpty {
                        appState.addTab(name: name, directory: dir)
                        dismiss()
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(name.isEmpty || directory == nil)
                .accessibilityIdentifier("new-tab-create-button")
            }
        }
        .padding(24)
        .frame(width: 420)
    }

    private func pickDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Select"
        if panel.runModal() == .OK, let url = panel.url {
            directoryPath = url.path
            if name.isEmpty {
                name = url.lastPathComponent
            }
        }
    }
}
