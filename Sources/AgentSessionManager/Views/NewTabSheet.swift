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
                    Spacer()
                    Button("Choose…") { pickDirectory() }
                        .buttonStyle(.bordered)
                }
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Create") {
                    if let dir = directory, !name.isEmpty {
                        appState.addTab(name: name, directory: dir)
                        dismiss()
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(name.isEmpty || directory == nil)
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
        if panel.runModal() == .OK {
            directory = panel.url
            if name.isEmpty, let url = panel.url {
                name = url.lastPathComponent
            }
        }
    }
}
