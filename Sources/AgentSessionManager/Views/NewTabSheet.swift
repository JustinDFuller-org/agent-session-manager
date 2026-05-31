import SwiftUI

struct NewTabSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var directory: URL?

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
                    Text(directory?.path ?? "No directory selected")
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(directory == nil ? .secondary : .primary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .accessibilityIdentifier("new-tab-directory-label")
                    Spacer()
                    Button("Choose…") {
                        if AgentSessionManagerApp.isUITesting {
                            directory = URL(fileURLWithPath: NSTemporaryDirectory())
                                .appending(path: "UITestWorkspace", directoryHint: .isDirectory)
                            if name.isEmpty { name = "UITestWorkspace" }
                            return
                        }
                        let panel = NSOpenPanel()
                        panel.canChooseFiles = false
                        panel.canChooseDirectories = true
                        panel.allowsMultipleSelection = false
                        panel.prompt = "Select"
                        if panel.runModal() == .OK {
                            directory = panel.url
                            if name.isEmpty, let url = panel.url {
                                name = url.lastPathComponent
                            }
                        }
                    }
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
                        let tab = Tab(name: name, directory: dir)
                        appState.tabs.append(tab)
                        appState.activeTabID = tab.id
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
}
