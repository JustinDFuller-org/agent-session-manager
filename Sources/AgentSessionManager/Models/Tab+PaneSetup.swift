import Foundation

extension Tab {
    /// Creates a pane with a loading overlay; terminal setup is deferred to `completeSetup`.
    @discardableResult
    func addPaneWithLoadingState(
        name: String,
        harness: Harness = .claude,
        worktreeIsManaged: Bool = false,
        profileID: UUID? = nil,
        scrollbackOverride: ScrollbackLimit? = nil,
        agentControlInjectionEnabled: Bool = true,
        appSettings: AppSettings? = nil
    ) -> Pane {
        TracingService.shared.record(
            "tab.pane.added",
            attributes: [
                "pane.name": name,
                "tab.name": self.name,
            ])
        let pane = Pane(
            name: name,
            tab: self,
            harness: harness,
            worktreeIsManaged: worktreeIsManaged,
            profileID: profileID,
            scrollbackOverride: scrollbackOverride,
            agentControlInjectionEnabled: agentControlInjectionEnabled,
            appSettings: appSettings
        )
        pane.setupState = .loading
        TracingService.shared.record(
            "agent_control.injection_decision.resolved",
            attributes: [
                "pane.id": pane.id.uuidString,
                "pane.name": pane.name,
                "tab.id": self.id.uuidString,
                "tab.name": self.name,
                "agent_control.enabled": String(pane.agentControlInjectionEnabled),
                "agent_control.policy": appSettings?.agentControlInjectionPolicy.rawValue ?? "default",
                "agent_control.scope": appSettings?.agentControlScope.rawValue ?? "default",
                "agent_control.source": "pane_loading",
            ])
        panes.append(pane)
        return pane
    }

    /// Finishes setup of a pane created by `addPaneWithLoadingState`: wires the terminal controller
    /// and clears the loading state.
    func completeSetup(
        for pane: Pane,
        resolved: ResolvedWorktree,
        managed: Bool,
        effectiveExtraArgs: [String],
        extraEnvVars: [String: String],
        statusLineConfigOverride: StatusLineConfig?,
        appSettings: AppSettings? = nil
    ) {
        pane.name = resolved.paneTitle
        pane.worktreeDirectory = resolved.processDirectory
        pane.worktreeIsManaged = managed
        pane.extraArgs = effectiveExtraArgs
        pane.extraEnvVars = extraEnvVars

        TracingService.shared.record(
            "tab.worktree.resolved",
            attributes: [
                "user_ref": pane.name,
                "result": "dir: \(resolved.processDirectory.path)",
                "path": resolved.processDirectory.path,
                "pane.name": pane.name,
                "pane.id": pane.id.uuidString,
                "tab.id": self.id.uuidString,
                "tab.name": self.name,
            ])

        let cwd = resolved.processDirectory.path

        if pane.harness != .shell && pane.harness != .opencode {
            let monitor = StatusLineMonitor(
                paneID: pane.id, paneName: pane.name,
                workingDirectory: cwd, harness: pane.harness, processStartTime: Date(),
                tabID: self.id, tabName: self.name,
                customFieldEnvironment: extraEnvVars)
            pane.installStatusLineMonitor(monitor)
        }

        let controller = TerminalController()
        controller.pendingEnvironment = Tab.hostEnvironmentForChildProcess()
        controller.pendingDirectory = cwd
        controller.pendingShell = appSettings.map { ShellResolver.resolved($0) }

        switch pane.harness {
        case .shell:
            controller.pendingCommandArgs = nil
        case .claude:
            applyExtraEnvVars(extraEnvVars, to: controller)
            controller.pendingCommandArgs = Tab.buildClaudeCommand(
                settingsPath: pane.statusLineMonitor!.settingsFilePath,
                extraArgs: effectiveExtraArgs
            )
        case .codex:
            applyExtraEnvVars(extraEnvVars, to: controller)
            pane.statusLineMonitor?.writeCodexHookScript()
            controller.pendingEnvironment =
                (controller.pendingEnvironment ?? [])
                + [
                    "AGENT_SESSION_MANAGER_PANE_ID=\(pane.id.uuidString)",
                    "AGENT_SESSION_MANAGER_TAB_ID=\(self.id.uuidString)",
                    "AGENT_SESSION_MANAGER_CODEX_HOOK_RECORD_PATH=\(pane.statusLineMonitor!.codexHookRecordFilePath)",
                ]
            controller.pendingCommandArgs = Tab.buildCodexCommand(
                hookScriptPath: pane.statusLineMonitor!.codexHookScriptFilePath,
                extraArgs: effectiveExtraArgs)
        case .cursor:
            applyExtraEnvVars(extraEnvVars, to: controller)
            controller.pendingEnvironment =
                (controller.pendingEnvironment ?? [])
                + ["AGENT_SESSION_MANAGER_PANE_ID=\(pane.id.uuidString)"]
            controller.pendingCommandArgs = ["agent"] + effectiveExtraArgs
        case .opencode:
            applyExtraEnvVars(extraEnvVars, to: controller)
            configureOpenCodeController(
                controller, pane: pane, extraArgs: effectiveExtraArgs, extraEnvVars: extraEnvVars,
                resumeSessionID: pane.opencodeSessionID)
            let monitor = StatusLineMonitor(
                paneID: pane.id, paneName: pane.name,
                workingDirectory: cwd, harness: pane.harness, processStartTime: Date(),
                tabID: self.id, tabName: self.name, opencodePort: pane.opencodePort,
                customFieldEnvironment: extraEnvVars)
            pane.installStatusLineMonitor(monitor)
        }
        controller.terminalView.telemetryTabName = self.name
        controller.terminalView.telemetryTabUUID = self.id
        controller.terminalView.telemetryPaneName = pane.name
        controller.terminalView.telemetryPaneUUID = pane.id
        guard prepareAgentControl(for: pane, controller: controller, appSettings: appSettings) else {
            return
        }
        pane.installTerminalController(controller)
        pane.setupState = nil
    }
}
