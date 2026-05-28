import SwiftUI

struct OnboardingWizardView: View {
    @Environment(AppSettings.self) private var appSettings
    @Environment(\.dismiss) private var dismiss

    private enum Step: Equatable {
        case welcome
        case shell
        case tools
    }

    @State private var step: Step = .welcome
    @State private var shellPickerSelection: String = ""
    @State private var customShellPath: String = ""
    @State private var isDetecting: Bool = false
    @State private var checkedTools: Set<CLIType> = []
    @State private var detectionRan: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            switch step {
            case .welcome:
                welcomeStep
            case .shell:
                shellStep
            case .tools:
                toolsStep
            }
        }
        .frame(width: 480)
        .onChange(of: step) { _, newStep in
            if newStep == .tools, !detectionRan {
                Task { await runDetection() }
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
                Button("Skip") { skip() }
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
                Button("Continue") { step = .tools }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("onboarding-shell-continue-button")
            }
        }
        .padding(32)
    }

    private var toolsStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("CLI Tools")
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
                    ForEach(CLIType.allCases, id: \.self) { tool in
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
                            Text(tool.cliCommandDescription)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            HStack {
                Spacer()
                Button("Done") { finish() }
                    .buttonStyle(.borderedProminent)
                    .disabled(isDetecting)
                    .accessibilityIdentifier("onboarding-done-button")
            }
        }
        .padding(32)
    }

    private func resolvedShell() -> String {
        if shellPickerSelection == "__other__" {
            let trimmed = customShellPath.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? ShellResolver.detectedLoginShell() : trimmed
        }
        return shellPickerSelection.isEmpty ? ShellResolver.detectedLoginShell() : shellPickerSelection
    }

    private func runDetection() async {
        guard !detectionRan else { return }
        detectionRan = true
        isDetecting = true
        let shell = resolvedShell()
        let found = await CLIToolDetector.detectInstalled(shell: shell)
        checkedTools = found
        isDetecting = false
    }

    private func finish() {
        let shell: String
        if shellPickerSelection == "__other__" {
            shell = customShellPath.trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            shell = shellPickerSelection
        }
        appSettings.preferredShell = shell
        SettingsPersistence.saveShellSettings(appSettings: appSettings)

        for tool in checkedTools {
            appSettings.setActive(tool, true)
        }
        if appSettings.activeTools.isEmpty {
            appSettings.setActive(.claude, true)
        }
        SettingsPersistence.saveActiveTools(appSettings: appSettings)

        appSettings.hasCompletedOnboarding = true
        SettingsPersistence.saveOnboarding(appSettings: appSettings)
        dismiss()
    }

    private func skip() {
        appSettings.hasCompletedOnboarding = true
        SettingsPersistence.saveOnboarding(appSettings: appSettings)
        dismiss()
    }
}
