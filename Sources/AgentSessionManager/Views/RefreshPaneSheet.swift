import SwiftUI

struct RefreshPaneSheet: View {
    @Environment(\.dismiss) private var dismiss
    let pane: Pane
    let onQuickRefresh: (Pane) -> Void
    let onRefreshWithSettings: (Pane) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Refresh Pane")
                .font(.headline)

            Text("Restart \"\(pane.name)\" with a fresh environment.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                Button {
                    onQuickRefresh(pane)
                    dismiss()
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Refresh and Continue")
                                .fontWeight(.medium)
                            Text("Restart with the same settings and --continue")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.bordered)
                .accessibilityIdentifier("refresh-pane-quick")

                Button {
                    onRefreshWithSettings(pane)
                    dismiss()
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Refresh with New Settings\u{2026}")
                                .fontWeight(.medium)
                            Text("Reconfigure CLI options before restarting")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("refresh-pane-settings")
            }

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                    .accessibilityIdentifier("refresh-pane-cancel")
            }
        }
        .padding(24)
        .frame(width: 320)
    }
}
