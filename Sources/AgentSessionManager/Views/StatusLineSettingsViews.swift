import SwiftUI

struct StatusLineEditorPhases: OptionSet {
    let rawValue: Int

    static let display = StatusLineEditorPhases(rawValue: 1 << 0)
    static let rows = StatusLineEditorPhases(rawValue: 1 << 1)
    static let full: StatusLineEditorPhases = [.display, .rows]
}

/// Facts, alignment, rows, and add-row controls for [`StatusLineConfig`]. Omit PR tracking —
/// that stays on [`AppSettings`].
struct StatusLineConfigLayoutEditor: View {
    @Binding var config: StatusLineConfig
    var filterCLI: Harness?
    let phases: StatusLineEditorPhases
    let onPersist: () -> Void

    var body: some View {
        Group {
            if phases.contains(.display) {
                Section("Display") {
                    LabeledContent {
                        Picker("Fact style", selection: factStylePickerBinding) {
                            ForEach(FactLabelStyle.allCases, id: \.self) { style in
                                Text(style.displayName).tag(style)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .frame(width: 160)
                    } label: {
                        Text("Fact style")
                            .font(.system(.body, design: .monospaced))
                            .fontWeight(.medium)
                    }
                    LabeledContent {
                        Picker("Item alignment", selection: rowAlignmentPickerBinding) {
                            ForEach(RowAlignment.allCases, id: \.self) { alignment in
                                Text(alignment.displayName).tag(alignment)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .frame(width: 160)
                    } label: {
                        Text("Item alignment")
                            .font(.system(.body, design: .monospaced))
                            .fontWeight(.medium)
                    }
                }
            }
            if phases.contains(.rows) {
                ForEach(Array(config.rows.indices), id: \.self) { rowIndex in
                    rowSection(rowIndex: rowIndex)
                }
                Section {
                    Button {
                        touch { $0.rows.append(StatusLineRow()) }
                    } label: {
                        Label("Add Row", systemImage: "plus")
                    }
                    .buttonStyle(.borderless)
                }
            }
        }
    }

    private var factStylePickerBinding: Binding<FactLabelStyle> {
        Binding(
            get: { config.factLabelStyle },
            set: { newVal in touch { $0.factLabelStyle = newVal } })
    }

    private var rowAlignmentPickerBinding: Binding<RowAlignment> {
        Binding(
            get: { config.rowAlignment },
            set: { newVal in touch { $0.rowAlignment = newVal } })
    }

    private func touch(_ update: (inout StatusLineConfig) -> Void) {
        var next = config
        update(&next)
        config = next
        onPersist()
    }

    private func unusedItemsEligibleForAddition() -> [StatusLineItem] {
        let base = StatusLineConfig.allItems.filter { !config.usedItemIDs.contains($0.id) }
        let filtered = filterCLI.map { cli in base.filter { $0.supportedBy(cli) } } ?? base
        return filtered.sorted { $0.label.localizedStandardCompare($1.label) == .orderedAscending }
    }

    @ViewBuilder
    private func availabilityBadge(for availability: ToolAvailability) -> some View {
        switch availability {
        case .claudeOnly:
            Text("Claude only")
                .font(.caption2)
                .foregroundStyle(.blue)
                .padding(.horizontal, 6)
                .padding(.vertical, 8)
                .background(Capsule().fill(Color.blue.opacity(0.1)))
        case .all:
            Text("All tools")
                .font(.caption2)
                .foregroundStyle(.green)
                .padding(.horizontal, 6)
                .padding(.vertical, 8)
                .background(Capsule().fill(Color.green.opacity(0.1)))
        }
    }

    private func rowSection(rowIndex: Int) -> some View {
        let rowCount = config.rows.count
        let available = unusedItemsEligibleForAddition()
        return Section {
            ForEach(config.rows[rowIndex].items) { item in
                HStack {
                    Image(systemName: item.sfSymbol)
                        .frame(width: 16)
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.label)
                            .font(.system(.body, design: .monospaced))
                            .fontWeight(.medium)
                        let desc = itemDescription(for: item.id)
                        if !desc.isEmpty {
                            Text(desc)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    availabilityBadge(for: item.availability)
                    Button(role: .destructive) {
                        touch {
                            $0.rows[rowIndex].items.removeAll { $0.id == item.id }
                        }
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.borderless)
                }
            }
            Menu {
                if available.isEmpty {
                    Text(filterCLI == nil ? "All items are already used" : "No more items supported for this harness")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(available) { item in
                        Button {
                            touch {
                                $0.rows[rowIndex].items.append(item)
                            }
                        } label: {
                            HStack {
                                Text(item.label)
                                switch item.availability {
                                case .claudeOnly:
                                    Text("Claude only")
                                        .font(.caption2)
                                        .foregroundStyle(.blue)
                                case .all:
                                    Text("All tools")
                                        .font(.caption2)
                                        .foregroundStyle(.green)
                                }
                            }
                        }
                    }
                }
            } label: {
                Label("Add Item", systemImage: "plus")
            }
            .buttonStyle(.borderless)
        } header: {
            HStack {
                Text("Row \(rowIndex + 1)")
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer()
                Button {
                    touch { $0.rows.swapAt(rowIndex, rowIndex - 1) }
                } label: {
                    Image(systemName: "chevron.up")
                }
                .buttonStyle(.borderless)
                .disabled(rowIndex == 0)
                Button {
                    touch { $0.rows.swapAt(rowIndex, rowIndex + 1) }
                } label: {
                    Image(systemName: "chevron.down")
                }
                .buttonStyle(.borderless)
                .disabled(rowIndex == rowCount - 1)
                Button(role: .destructive) {
                    touch { $0.rows.remove(at: rowIndex) }
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(.red)
                }
                .buttonStyle(.borderless)
            }
        }
    }

    private func itemDescription(for id: String) -> String {
        switch id {
        case "model": return "Claude model name"
        case "worktree": return "Git worktree name and current branch"
        case "cost": return "Total session cost in USD (Claude only)"
        case "context": return "Context window usage with progress bar (Claude only)"
        case "effort": return "Effort level (Claude only)"
        case "thinking": return "Whether extended thinking is on or off (Claude only)"
        case "vimMode": return "Vim editor mode (Claude only)"
        case "agentName": return "Agent name (Claude only)"
        case "sessionName": return "Session name (Claude only)"
        case "linesAdded": return "Lines added vs HEAD (git diff --shortstat HEAD)"
        case "linesRemoved": return "Lines removed vs HEAD (git diff --shortstat HEAD)"
        case "duration": return "Total session duration"
        case "contextRemaining": return "Context window remaining percentage (Claude only)"
        case "inputTokens": return "Total input tokens used (Claude only)"
        case "outputTokens": return "Total output tokens used (Claude only)"
        case "rate5h": return "5-hour rate limit usage with progress bar (Claude only)"
        case "rate7d": return "7-day rate limit usage with progress bar (Claude only)"
        case "rate5hReset": return "Time until 5-hour rate limit resets (Claude only)"
        case "rate7dReset": return "Time until 7-day rate limit resets (Claude only)"
        case "version": return "Tool CLI version"
        case "outputStyle": return "Output style name (Claude only)"
        case "exceeds200k": return "Warning when context exceeds 200k tokens (Claude only)"
        case "pr": return "GitHub pull request status for the current branch"
        case "profileName": return "Selected profile name when the pane uses one"
        default: return ""
        }
    }
}

struct StatusLineContent: View {
    @Environment(AppSettings.self) private var appSettings

    var body: some View {
        @Bindable var appSettings = appSettings
        Form {
            StatusLineConfigLayoutEditor(
                config: $appSettings.statusLineConfig,
                filterCLI: nil,
                phases: .display,
                onPersist: {
                    SettingsPersistence.saveStatusLine(appSettings: appSettings)
                })
            Section("GitHub PR Tracking") {
                SettingRow(
                    title: "Track pull requests",
                    description:
                        "Detects the PR for the current git branch and shows its status in the status line. "
                        + "Requires the GitHub CLI (gh) installed and authenticated."
                ) {
                    Toggle("Track pull requests", isOn: $appSettings.githubPRTrackingEnabled)
                        .toggleStyle(.checkbox)
                        .labelsHidden()
                        .onChange(of: appSettings.githubPRTrackingEnabled) {
                            SettingsPersistence.savePRTracking(appSettings: appSettings)
                            NotificationCenter.default.post(
                                name: .agentSessionManagerPRTrackingSettingChanged, object: nil)
                        }
                        .accessibilityIdentifier("settings-pr-tracking-toggle")
                }
                SettingRow(
                    title: "PR Polling Interval",
                    description:
                        "How often to check for PR updates across all panes (min 15s). Uses a single batched "
                        + "GraphQL request per cycle — the rate limit auto-adjusts at high pane counts.",
                    defaultValue: "30 seconds"
                ) {
                    HStack(spacing: 4) {
                        TextField(
                            "",
                            text: Binding(
                                get: { String(appSettings.prPollingIntervalSeconds) },
                                set: { newValue in
                                    if let parsed = Int(newValue) {
                                        appSettings.prPollingIntervalSeconds = max(15, parsed)
                                        SettingsPersistence.savePRPollingSettings(appSettings: appSettings)
                                    }
                                }
                            )
                        )
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                        .frame(width: 72)
                        .accessibilityIdentifier("settings-pr-polling-interval-field")
                        Text("seconds")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                SettingRow(
                    title: "Request Timeout",
                    description:
                        "Cancel the in-flight request and wait for the next cycle if it takes longer "
                        + "than this (min 5s).",
                    defaultValue: "15 seconds"
                ) {
                    HStack(spacing: 4) {
                        TextField(
                            "",
                            text: Binding(
                                get: { String(appSettings.prRequestTimeoutSeconds) },
                                set: { newValue in
                                    if let parsed = Int(newValue) {
                                        appSettings.prRequestTimeoutSeconds = max(5, parsed)
                                        SettingsPersistence.savePRPollingSettings(appSettings: appSettings)
                                    }
                                }
                            )
                        )
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                        .frame(width: 72)
                        .accessibilityIdentifier("settings-pr-request-timeout-field")
                        Text("seconds")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                SettingRow(
                    title: "Background Refresh",
                    description:
                        "Keep checking for PR updates while the app is in the background at a reduced rate. "
                        + "Disable to pause all polling when the app is not focused."
                ) {
                    Toggle("Background Refresh", isOn: $appSettings.prBackgroundRefreshEnabled)
                        .toggleStyle(.checkbox)
                        .labelsHidden()
                        .onChange(of: appSettings.prBackgroundRefreshEnabled) {
                            SettingsPersistence.savePRPollingSettings(appSettings: appSettings)
                        }
                        .accessibilityIdentifier("settings-pr-background-refresh-toggle")
                }
                SettingRow(
                    title: "Background Polling Interval",
                    description: "How often to check for PR updates while the app is in the background (min 15s).",
                    defaultValue: "60 seconds"
                ) {
                    HStack(spacing: 4) {
                        TextField(
                            "",
                            text: Binding(
                                get: { String(appSettings.prBackgroundPollingIntervalSeconds) },
                                set: { newValue in
                                    if let parsed = Int(newValue) {
                                        appSettings.prBackgroundPollingIntervalSeconds = max(15, parsed)
                                        SettingsPersistence.savePRPollingSettings(appSettings: appSettings)
                                    }
                                }
                            )
                        )
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                        .frame(width: 72)
                        .accessibilityIdentifier("settings-pr-background-interval-field")
                        Text("seconds")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .opacity(appSettings.prBackgroundRefreshEnabled ? 1 : 0.4)
                .disabled(!appSettings.prBackgroundRefreshEnabled)
            }
            StatusLineConfigLayoutEditor(
                config: $appSettings.statusLineConfig,
                filterCLI: nil,
                phases: .rows,
                onPersist: {
                    SettingsPersistence.saveStatusLine(appSettings: appSettings)
                })
        }
        .formStyle(.grouped)
    }
}

struct EnvVarOptionRow: View {
    @Binding var option: EnvVarConfig
    let onChange: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(option.id)
                        .font(.system(.body, design: .monospaced))
                        .fontWeight(.medium)
                    Text(option.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 4) {
                        Text("Show")
                            .font(.caption)
                        Toggle("Show", isOn: $option.isAvailable)
                            .toggleStyle(.checkbox)
                            .labelsHidden()
                            .onChange(of: option.isAvailable) {
                                if !option.isAvailable {
                                    option.isDefaultEnabled = false
                                }
                                onChange()
                            }
                    }
                    HStack(spacing: 4) {
                        Text("Default on")
                            .font(.caption)
                        Toggle("Default on", isOn: $option.isDefaultEnabled)
                            .toggleStyle(.checkbox)
                            .labelsHidden()
                            .disabled(!option.isAvailable)
                            .onChange(of: option.isDefaultEnabled) { onChange() }
                    }
                }
            }
            if option.isAvailable {
                HStack(spacing: 8) {
                    Text("Default value")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("Value", text: $option.defaultValue)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                        .frame(maxWidth: .infinity)
                        .onChange(of: option.defaultValue) { onChange() }
                }
            }
        }
        .padding(.vertical, 8)
    }
}

struct CustomEnvVarOptionRow: View {
    @Binding var option: EnvVarConfig
    let onChange: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(option.id)
                    .font(.system(.body, design: .monospaced))
                    .fontWeight(.medium)
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 4) {
                        Text("Show")
                            .font(.caption)
                        Toggle("Show", isOn: $option.isAvailable)
                            .toggleStyle(.checkbox)
                            .labelsHidden()
                            .onChange(of: option.isAvailable) {
                                if !option.isAvailable {
                                    option.isDefaultEnabled = false
                                }
                                onChange()
                            }
                    }
                    HStack(spacing: 4) {
                        Text("Default on")
                            .font(.caption)
                        Toggle("Default on", isOn: $option.isDefaultEnabled)
                            .toggleStyle(.checkbox)
                            .labelsHidden()
                            .disabled(!option.isAvailable)
                            .onChange(of: option.isDefaultEnabled) { onChange() }
                    }
                }
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundStyle(.red)
                }
                .buttonStyle(.borderless)
                .padding(.leading, 8)
            }
            if option.isAvailable {
                HStack(spacing: 8) {
                    Text("Default value")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("Value", text: $option.defaultValue)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                        .frame(maxWidth: .infinity)
                        .onChange(of: option.defaultValue) { onChange() }
                }
            }
        }
        .padding(.vertical, 8)
    }
}

struct AddCustomEnvVarSheet: View {
    @Environment(\.dismiss) private var dismiss

    let existingIDs: [String]
    let onAdd: (String) -> Void

    @State private var varName = ""

    private var isValid: Bool {
        let trimmed = varName.trimmingCharacters(in: .whitespaces)
        return !trimmed.isEmpty && !existingIDs.contains(trimmed)
            && trimmed.range(of: "^[A-Za-z_][A-Za-z0-9_]*$", options: .regularExpression) != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Add Custom Env Var")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                Text("Variable Name")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                TextField("MY_CUSTOM_VAR", text: $varName)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                    .onSubmit { if isValid { submit() } }
                if !varName.isEmpty && existingIDs.contains(varName) {
                    Text("An environment variable with this name already exists.")
                        .font(.caption)
                        .foregroundStyle(.red)
                } else if !varName.isEmpty && !isValid {
                    Text(
                        "Variable name must start with a letter or underscore and contain only letters, digits, or underscores."
                    )
                    .font(.caption)
                    .foregroundStyle(.red)
                }
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Add") { submit() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!isValid)
            }
        }
        .padding(24)
        .frame(width: 420)
    }

    private func submit() {
        guard isValid else { return }
        onAdd(varName.trimmingCharacters(in: .whitespaces))
        dismiss()
    }
}

struct AddCustomFlagSheet: View {
    @Environment(\.dismiss) private var dismiss

    let existingIDs: [String]
    let onAdd: (String, Bool) -> Void

    @State private var flagName = ""
    @State private var isString = false

    private var isValid: Bool {
        !flagName.isEmpty && flagName.hasPrefix("--") && !existingIDs.contains(flagName)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Add Custom Flag")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                Text("Flag Name")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                TextField("--my-flag", text: $flagName)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                    .onSubmit { if isValid { submit() } }
                if !flagName.isEmpty && !flagName.hasPrefix("--") {
                    Text("Flag name must start with \"--\".")
                        .font(.caption)
                        .foregroundStyle(.red)
                } else if !flagName.isEmpty && existingIDs.contains(flagName) {
                    Text("A flag with this name already exists.")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Flag Type")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Picker("Flag Type", selection: $isString) {
                    Text("Boolean").tag(false)
                    Text("Text").tag(true)
                }
                .pickerStyle(.radioGroup)
                .labelsHidden()
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Add") { submit() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!isValid)
            }
        }
        .padding(24)
        .frame(width: 320)
    }

    private func submit() {
        guard isValid else { return }
        onAdd(flagName, isString)
        dismiss()
    }
}

struct NotificationsContent: View {
    @Environment(AppSettings.self) private var appSettings

    var body: some View {
        @Bindable var appSettings = appSettings
        Form {
            Section("macOS") {
                LabeledContent {
                    Toggle("Banner Notifications", isOn: $appSettings.isMacOSBannerNotificationsEnabled)
                        .toggleStyle(.checkbox)
                        .labelsHidden()
                        .accessibilityIdentifier("settings-macos-banner-notifications-toggle")
                        .onChange(of: appSettings.isMacOSBannerNotificationsEnabled) {
                            SettingsPersistence.saveNotificationSettings(appSettings: appSettings)
                        }
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Banner Notifications")
                            .font(.system(.body, design: .monospaced))
                            .fontWeight(.medium)
                        Text(
                            "Show a system notification when a background pane rings the bell. "
                                + "Requires permission in System Settings."
                        )
                        .font(.caption).foregroundStyle(.secondary)
                        Text(
                            "By default, macOS banners auto-dismiss after a few seconds. "
                                + "To keep them on screen until dismissed:"
                        )
                        .font(.caption).foregroundStyle(.secondary).padding(.top, 2)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("1. Click Open Notification Settings below.")
                            Text("2. Find Agent Session Manager in the list.")
                            Text("3. Set Alert Style to Persistent.")
                        }
                        .font(.caption).foregroundStyle(.secondary)
                        Button("Open Notification Settings") {
                            // swiftlint:disable:next force_unwrapping
                            let url = URL(
                                string: "x-apple.systempreferences:com.apple.preference.notifications"
                            )!
                            NSWorkspace.shared.open(url)
                        }
                        .font(.caption).buttonStyle(.link)
                        .accessibilityIdentifier("settings-open-notification-settings-button")
                    }
                }
            }
            Section("Cursor") {
                SettingRow(
                    title: "Stop hook for attention",
                    description:
                        "Install a Cursor stop hook so the app is notified when the agent finishes "
                        + "a turn (plan ready, task complete, etc.)."
                ) {
                    Toggle(
                        "Stop hook for attention",
                        isOn: $appSettings.isCursorNotificationHookAttentionEnabled
                    )
                    .toggleStyle(.checkbox)
                    .labelsHidden()
                    .accessibilityIdentifier("settings-cursor-notification-hook-toggle")
                    .onChange(of: appSettings.isCursorNotificationHookAttentionEnabled) {
                        SettingsPersistence.saveNotificationSettings(appSettings: appSettings)
                    }
                }
            }
            Section("Sidebar") {
                SettingRow(
                    title: "Sidebar Position",
                    description: "Which side the notification sidebar appears on."
                ) {
                    Picker("Sidebar Position", selection: $appSettings.notificationSidebarSide) {
                        ForEach(SidebarSide.allCases, id: \.self) { side in
                            Text(side.displayName).tag(side)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 120)
                    .accessibilityIdentifier("settings-sidebar-side")
                    .onChange(of: appSettings.notificationSidebarSide) {
                        SettingsPersistence.saveNotificationSettings(appSettings: appSettings)
                    }
                }
                SettingRow(
                    title: "Always Show Notifications Bar",
                    description: "Keep the notifications sidebar visible even when there are no notifications."
                ) {
                    Toggle("Always Show Notifications Bar", isOn: $appSettings.alwaysShowNotificationsSidebar)
                        .toggleStyle(.checkbox)
                        .labelsHidden()
                        .accessibilityIdentifier("settings-always-show-notifications-bar-toggle")
                        .onChange(of: appSettings.alwaysShowNotificationsSidebar) {
                            SettingsPersistence.saveNotificationSettings(appSettings: appSettings)
                        }
                }
            }
            Section("Priority") {
                SettingRow(
                    title: "Priority Notifications",
                    description:
                        "Allow panes to be marked as priority. Priority notifications appear at the top "
                        + "of the sidebar."
                ) {
                    Toggle("Priority Notifications", isOn: $appSettings.isPriorityNotificationsEnabled)
                        .toggleStyle(.checkbox)
                        .labelsHidden()
                        .accessibilityIdentifier("settings-priority-notifications-toggle")
                        .onChange(of: appSettings.isPriorityNotificationsEnabled) {
                            SettingsPersistence.saveNotificationSettings(appSettings: appSettings)
                        }
                }
            }
            Section("GitHub PR") {
                SettingRow(
                    title: "PR Merged Notifications",
                    description: "Show a sidebar notification and macOS banner when a tracked PR is merged."
                ) {
                    Toggle("PR Merged Notifications", isOn: $appSettings.isPRMergedNotificationsEnabled)
                        .toggleStyle(.checkbox)
                        .labelsHidden()
                        .accessibilityIdentifier("settings-pr-merged-notifications-toggle")
                        .onChange(of: appSettings.isPRMergedNotificationsEnabled) {
                            SettingsPersistence.saveNotificationSettings(appSettings: appSettings)
                        }
                }
            }
        }
        .formStyle(.grouped)
    }
}
