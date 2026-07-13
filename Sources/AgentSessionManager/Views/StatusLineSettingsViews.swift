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
                    .pinnedListRowBackground()
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
                    .pinnedListRowBackground()
                    LabeledContent {
                        Toggle("", isOn: showPercentagesAsTextBinding)
                            .labelsHidden()
                            .accessibilityIdentifier("settings-statusline-percentages-text-toggle")
                    } label: {
                        Text("Show percentages as text")
                            .font(.system(.body, design: .monospaced))
                            .fontWeight(.medium)
                    }
                    .pinnedListRowBackground()
                }
            }
            if phases.contains(.rows) {
                ForEach(Array(config.rows.indices), id: \.self) { rowIndex in
                    let rowCount = config.rows.count
                    let base = StatusLineConfig.allItems.filter { !config.usedItemIDs.contains($0.id) }
                    let filtered = filterCLI.map { cli in base.filter { $0.supportedBy(cli) } } ?? base
                    let available = filtered.sorted { $0.label.localizedStandardCompare($1.label) == .orderedAscending }
                    Section {
                        ForEach(config.rows[rowIndex].items) { item in
                            HStack {
                                Image(systemName: item.sfSymbol)
                                    .frame(width: 16)
                                    .foregroundStyle(.secondary)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.label)
                                        .font(.system(.body, design: .monospaced))
                                        .fontWeight(.medium)
                                    let descriptions = [
                                        "model": "Claude model name",
                                        "worktree": "Git worktree name and current branch",
                                        "cost": "Total session cost in USD (Claude only)",
                                        "context": "Context window used (progress bar or text)",
                                        "effort": "Effort level (Claude only)",
                                        "thinking": "Whether extended thinking is on or off (Claude only)",
                                        "vimMode": "Vim editor mode (Claude only)",
                                        "agentName": "Agent name (Claude only)",
                                        "sessionName": "Session name (Claude only)",
                                        "linesAdded": "Lines added vs HEAD (git diff --shortstat HEAD)",
                                        "linesRemoved": "Lines removed vs HEAD (git diff --shortstat HEAD)",
                                        "duration": "Total session duration",
                                        "contextRemaining": "Context window remaining (progress bar or text)",
                                        "inputTokens": "Total input tokens used",
                                        "outputTokens": "Total output tokens used",
                                        "rate5h": "5-hour rate limit usage with progress bar",
                                        "rate7d": "7-day rate limit usage with progress bar",
                                        "rate5hReset": "Time until 5-hour rate limit resets",
                                        "rate7dReset": "Time until 7-day rate limit resets",
                                        "version": "Tool CLI version",
                                        "outputStyle": "Output style name (Claude only)",
                                        "exceeds200k": "Warning when context exceeds 200k tokens (Claude only)",
                                        "pr": "GitHub pull request status for the current branch",
                                        "profileName": "Selected profile name when the pane uses one",
                                        "repo": "Git repository host, owner, and name (e.g. owner/repo)",
                                        "contextSize": "Total context window size in tokens (Claude only)",
                                        "cacheRead": "Cache read input tokens this session (Claude only)",
                                        "cacheCreation": "Cache creation input tokens this session (Claude only)",
                                        "apiDuration": "Total API request time in milliseconds (Claude only)",
                                    ]
                                    if let description = descriptions[item.id] {
                                        Text(description)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                Text(capabilityLabel(for: item))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 8)
                                    .background(Capsule().fill(Color.secondary.opacity(0.1)))
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
                                Text(
                                    filterCLI == nil
                                        ? "All items are already used" : "No more items supported for this harness"
                                )
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
                                            Text(capabilityLabel(for: item))
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
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

    private var showPercentagesAsTextBinding: Binding<Bool> {
        Binding(
            get: { config.showPercentagesAsText },
            set: { newVal in touch { $0.showPercentagesAsText = newVal } })
    }

    private func touch(_ update: (inout StatusLineConfig) -> Void) {
        var next = config
        update(&next)
        config = next
        onPersist()
    }

    private func capabilityLabel(for item: StatusLineItem) -> String {
        let harnesses = item.capability.supportedHarnesses
        if harnesses == StatusLineConfig.allHarnesses {
            return "All tools"
        }
        return Harness.allCases
            .filter { harnesses.contains($0) }
            .map(\.displayName)
            .joined(separator: ", ")
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
                            SettingsPersistence.save(
                                appSettings.githubPRTrackingEnabled, to: "pr-tracking-settings.json")
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
        .pinnedFormBackground()
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
            Section("Claude") {
                SettingRow(
                    title: "Notify when Claude stops",
                    description: "Show a banner and sidebar row when Claude finishes a turn."
                ) {
                    Toggle(
                        "Notify when Claude stops",
                        isOn: $appSettings.isClaudeStopNotificationEnabled
                    )
                    .toggleStyle(.checkbox)
                    .labelsHidden()
                    .accessibilityIdentifier("settings-claude-stop-notification-toggle")
                    .onChange(of: appSettings.isClaudeStopNotificationEnabled) {
                        SettingsPersistence.saveNotificationSettings(appSettings: appSettings)
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
                SettingRow(
                    title: "PR Closed Notifications",
                    description:
                        "Show a sidebar notification and macOS banner when a tracked PR is closed without merging."
                ) {
                    Toggle("PR Closed Notifications", isOn: $appSettings.isPRClosedNotificationsEnabled)
                        .toggleStyle(.checkbox)
                        .labelsHidden()
                        .accessibilityIdentifier("settings-pr-closed-notifications-toggle")
                        .onChange(of: appSettings.isPRClosedNotificationsEnabled) {
                            SettingsPersistence.saveNotificationSettings(appSettings: appSettings)
                        }
                }
            }
        }
        .formStyle(.grouped)
        .pinnedFormBackground()
    }
}
