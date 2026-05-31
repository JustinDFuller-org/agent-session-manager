import SwiftUI

struct OnboardingWizardView: View {
    @Environment(AppSettings.self) private var appSettings
    @Environment(\.dismiss) private var dismiss

    private enum Step: Equatable {
        case welcome
        case shell
        case tools
        case statusLine
        case cliFlags
        case profiles
    }

    @State private var step: Step = .welcome
    @State private var shellPickerSelection: String = ""
    @State private var customShellPath: String = ""
    @State private var isDetecting: Bool = false
    @State private var checkedTools: Set<Harness> = []
    @State private var detectionRan: Bool = false
    @State private var draftConfig: StatusLineConfig = .wizardDefault()
    @State private var draftCliOptions: [Harness: [CLIOptionConfig]] = [:]
    @State private var draftEnvVars: [EnvVarConfig] = []
    @State private var cliFlagsTool: Harness = .claude

    var body: some View {
        VStack(spacing: 0) {
            switch step {
            case .welcome:
                welcomeStep
            case .shell:
                shellStep
            case .tools:
                toolsStep
            case .statusLine:
                statusLineStep
            case .cliFlags:
                cliFlagsStep
            case .profiles:
                profilesStep
            }
        }
        .frame(width: 520)
        .onChange(of: step) { _, newStep in
            if newStep == .tools, !detectionRan {
                Task {
                    guard !detectionRan else { return }
                    detectionRan = true
                    isDetecting = true
                    let shell: String
                    if shellPickerSelection == "__other__" {
                        let trimmed = customShellPath.trimmingCharacters(in: .whitespacesAndNewlines)
                        shell = trimmed.isEmpty ? ShellResolver.detectedLoginShell() : trimmed
                    } else {
                        shell = shellPickerSelection.isEmpty ? ShellResolver.detectedLoginShell() : shellPickerSelection
                    }
                    checkedTools = await HarnessDetector.detectInstalled(shell: shell)
                    isDetecting = false
                }
            }
            if newStep == .cliFlags {
                let toolsToSeed = checkedTools.isEmpty ? [Harness.claude] : Array(checkedTools)
                for tool in Harness.allCases where toolsToSeed.contains(tool) {
                    if draftCliOptions[tool] == nil {
                        draftCliOptions[tool] = CLIOptionConfig.recommendedDefaults(for: tool)
                    }
                }
                if draftEnvVars.isEmpty {
                    draftEnvVars = EnvVarConfig.recommendedDefaults()
                }
                if let first = Harness.allCases.first(where: { toolsToSeed.contains($0) }) {
                    cliFlagsTool = first
                }
            }
        }
    }

    private var welcomeStep: some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 48))
                    .foregroundStyle(Color.accentColor)
                Text("Welcome to Agent Session Manager")
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)
                Text(
                    "Set up your shell and detect which AI coding tools are installed. This only runs once — you can change these settings later."
                )
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            }
            HStack(spacing: 12) {
                Button("Skip") { finish() }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("onboarding-skip-button")
                Button("Set Up") { step = .shell }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("onboarding-setup-button")
            }
        }
        .padding(32)
    }

    private var shellStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Shell")
                    .font(.title2.bold())
                Text(
                    "Agents run inside an interactive shell so tools on your PATH (nvm, homebrew, etc.) are available."
                )
                .font(.body)
                .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Detected: \(ShellResolver.detectedLoginShell())")
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.secondary)

                Picker("Shell", selection: $shellPickerSelection) {
                    Text("Auto-detect (\(ShellResolver.detectedLoginShell()))").tag("")
                    ForEach(ShellResolver.commonShells, id: \.self) { shell in
                        Text(shell).tag(shell)
                    }
                    Text("Other\u{2026}").tag("__other__")
                }
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("onboarding-shell-picker")

                if shellPickerSelection == "__other__" {
                    TextField("Shell path, e.g. /bin/zsh", text: $customShellPath)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                        .accessibilityIdentifier("onboarding-shell-custom-field")
                }
            }

            HStack {
                Spacer()
                Button("Continue") {
                    appSettings.preferredShell =
                        shellPickerSelection == "__other__"
                        ? customShellPath.trimmingCharacters(in: .whitespacesAndNewlines)
                        : shellPickerSelection
                    SettingsPersistence.saveShellSettings(appSettings: appSettings)
                    step = .tools
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("onboarding-shell-continue-button")
            }
        }
        .padding(32)
    }

    private var toolsStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Harnesses")
                    .font(.title2.bold())
                Text("Select which tools to enable. Detected tools are pre-checked.")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            if isDetecting {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Detecting installed tools\u{2026}")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .accessibilityIdentifier("onboarding-detecting-indicator")
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(Harness.allCases, id: \.self) { tool in
                        HStack(spacing: 10) {
                            Toggle(
                                tool.displayName,
                                isOn: Binding(
                                    get: { checkedTools.contains(tool) },
                                    set: { on in
                                        if on {
                                            checkedTools.insert(tool)
                                        } else {
                                            checkedTools.remove(tool)
                                        }
                                    }
                                )
                            )
                            .toggleStyle(.checkbox)
                            .accessibilityIdentifier("onboarding-tool-toggle-\(tool.rawValue)")
                            Text(tool.commandDescription)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            HStack {
                Spacer()
                Button("Continue") {
                    for tool in checkedTools {
                        appSettings.setActive(tool, true)
                    }
                    if appSettings.activeTools.isEmpty {
                        appSettings.setActive(.claude, true)
                    }
                    SettingsPersistence.saveActiveTools(appSettings: appSettings)
                    step = .statusLine
                }
                .buttonStyle(.borderedProminent)
                .disabled(isDetecting)
                .accessibilityIdentifier("onboarding-done-button")
            }
        }
        .padding(32)
    }

    private var isDraftWizardDefault: Bool {
        let def = StatusLineConfig.wizardDefault()
        return draftConfig.factLabelStyle == def.factLabelStyle
            && draftConfig.rowAlignment == def.rowAlignment
            && draftConfig.rows.map(\.items) == def.rows.map(\.items)
    }

    private var statusLineStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Status Line")
                    .font(.title2.bold())
                Text(
                    "Customize the bottom-of-pane status bar. Skip to turn it off — you can configure it later in Settings."
                )
                .font(.body)
                .foregroundStyle(.secondary)
            }

            Form {
                StatusLineConfigLayoutEditor(
                    config: $draftConfig,
                    filterCLI: nil,
                    phases: .full,
                    onPersist: {}
                )
            }
            .formStyle(.grouped)
            .frame(maxHeight: 420)

            if isDraftWizardDefault {
                Button("Clear") {
                    draftConfig.rows = []
                }
                .buttonStyle(.link)
                .accessibilityIdentifier("onboarding-statusline-clear-button")
            } else {
                Button("Reset to Default") {
                    draftConfig = .wizardDefault()
                }
                .buttonStyle(.link)
                .accessibilityIdentifier("onboarding-statusline-reset-button")
            }

            HStack {
                Spacer()
                Button("Skip") {
                    draftConfig.rows = []
                    appSettings.statusLineConfig = draftConfig
                    SettingsPersistence.saveStatusLine(appSettings: appSettings)
                    step = .cliFlags
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("onboarding-statusline-skip-button")
                Button("Save") {
                    appSettings.statusLineConfig = draftConfig
                    SettingsPersistence.saveStatusLine(appSettings: appSettings)
                    step = .cliFlags
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("onboarding-statusline-save-button")
            }
        }
        .padding(32)
    }

    private var enabledToolsList: [Harness] {
        let tools = Harness.allCases.filter { checkedTools.contains($0) }
        return tools.isEmpty ? [.claude] : tools
    }

    private var isCurrentDraftRecommended: Bool {
        let draft = draftCliOptions[cliFlagsTool] ?? []
        let recommended = CLIOptionConfig.recommendedDefaults(for: cliFlagsTool)
        guard draft.count == recommended.count else { return false }
        let recMap = Dictionary(uniqueKeysWithValues: recommended.map { ($0.id, $0) })
        let cliFlagsMatch = draft.allSatisfy { opt in
            guard let rec = recMap[opt.id] else { return false }
            return opt.isAvailable == rec.isAvailable && opt.isDefaultEnabled == rec.isDefaultEnabled
        }
        guard cliFlagsMatch else { return false }
        if cliFlagsTool == .claude {
            let recommendedEnv = EnvVarConfig.recommendedDefaults()
            let recEnvMap = Dictionary(uniqueKeysWithValues: recommendedEnv.map { ($0.id, $0) })
            return draftEnvVars.allSatisfy { opt in
                guard let rec = recEnvMap[opt.id] else { return false }
                return opt.isAvailable == rec.isAvailable
            }
        }
        return true
    }

    private var cliFlagsStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("CLI Flags")
                    .font(.title2.bold())
                Text(
                    "Flags are passed when a pane starts. These recommendations surface the most-used options in the New Pane sheet — you can configure them later in Settings \u{2192} CLI Tools."
                )
                .font(.body)
                .foregroundStyle(.secondary)
            }

            if enabledToolsList.count > 1 {
                Picker("Tool", selection: $cliFlagsTool) {
                    ForEach(enabledToolsList, id: \.self) { tool in
                        Text(tool.displayName).tag(tool)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("onboarding-cliflags-tool-picker")
            }

            Form {
                CLIOptionsContent(
                    options: Binding(
                        get: { draftCliOptions[cliFlagsTool] ?? [] },
                        set: { draftCliOptions[cliFlagsTool] = $0 }
                    ),
                    onSave: {},
                    customFlagFooter:
                        "Custom flags may not be recognized by all \(cliFlagsTool.displayName) CLI versions.",
                    envVarOptions: cliFlagsTool == .claude ? $draftEnvVars : nil,
                    onEnvVarSave: cliFlagsTool == .claude ? {} : nil
                )
            }
            .formStyle(.grouped)
            .frame(maxHeight: 380)

            if isCurrentDraftRecommended {
                Button("Clear") {
                    if var draft = draftCliOptions[cliFlagsTool] {
                        for i in draft.indices {
                            draft[i].isAvailable = false
                            draft[i].isDefaultEnabled = false
                        }
                        draftCliOptions[cliFlagsTool] = draft
                    }
                    if cliFlagsTool == .claude {
                        for i in draftEnvVars.indices {
                            draftEnvVars[i].isAvailable = false
                            draftEnvVars[i].isDefaultEnabled = false
                        }
                    }
                }
                .buttonStyle(.link)
                .accessibilityIdentifier("onboarding-cliflags-clear-button")
            } else {
                Button("Reset to Recommended") {
                    draftCliOptions[cliFlagsTool] = CLIOptionConfig.recommendedDefaults(for: cliFlagsTool)
                    if cliFlagsTool == .claude {
                        draftEnvVars = EnvVarConfig.recommendedDefaults()
                    }
                }
                .buttonStyle(.link)
                .accessibilityIdentifier("onboarding-cliflags-reset-button")
            }

            HStack {
                Spacer()
                Button("Skip") { step = .profiles }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("onboarding-cliflags-skip-button")
                Button("Save") {
                    let toolsToSave = checkedTools.isEmpty ? [Harness.claude] : Array(checkedTools)
                    for tool in Harness.allCases where toolsToSave.contains(tool) {
                        guard let draft = draftCliOptions[tool] else { continue }
                        switch tool {
                        case .claude:
                            appSettings.cliOptions = draft
                            SettingsPersistence.save(appSettings: appSettings)
                        case .codex:
                            appSettings.codexCliOptions = draft
                            SettingsPersistence.saveCodexOptions(appSettings: appSettings)
                        case .cursor:
                            appSettings.cursorCliOptions = draft
                            SettingsPersistence.saveCursorOptions(appSettings: appSettings)
                        case .shell:
                            break
                        }
                    }
                    if toolsToSave.contains(.claude) {
                        appSettings.envVarOptions = draftEnvVars
                        SettingsPersistence.saveEnvVarOptions(appSettings: appSettings)
                    }
                    step = .profiles
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("onboarding-cliflags-save-button")
            }
        }
        .padding(32)
    }

    private var profilesStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Profiles")
                    .font(.title2.bold())
                Text(
                    "Profiles save a named set of flags and env vars so new panes start preconfigured. Creating a profile is optional."
                )
                .font(.body)
                .foregroundStyle(.secondary)
            }

            ProfilesContent()
                .frame(maxHeight: 380)

            HStack {
                Spacer()
                Button("Finish") { finish() }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("onboarding-profiles-finish-button")
            }
        }
        .padding(32)
    }

    private func finish() {
        appSettings.hasCompletedOnboarding = true
        SettingsPersistence.save(
            SettingsPersistence.OnboardingSettings(completed: appSettings.hasCompletedOnboarding),
            to: "onboarding-settings.json")
        dismiss()
    }
}
