import Foundation

extension Pane {
    /// Hooks the pane's notification sources into `AppState` notification UI (sidebar and dots).
    @MainActor
    func bindNotifications(appState: AppState, isPriority: Bool) {
        self.isPriority = isPriority
        notificationAppState = appState
        attachTerminalNotificationHandlers()
        attachStatusLineNotificationHandlers()
    }

    @MainActor
    func attachTerminalNotificationHandlers() {
        guard let appState = notificationAppState, let tab else { return }
        terminalController?.terminalView.onUserInput = { [weak appState, weak self] in
            Task { @MainActor in
                guard let appState, let pane = self else { return }
                appState.clearNotification(paneID: pane.id)
            }
        }
        terminalController?.onAttention = { [weak appState, weak tab, weak self] event in
            Task { @MainActor in
                guard let appState, let tab, let pane = self else { return }
                appState.addNotification(
                    paneID: pane.id,
                    paneName: pane.name,
                    tabID: tab.id,
                    tabName: tab.name,
                    isPriority: pane.isPriority,
                    event: event
                )
            }
        }
    }

    @MainActor
    func attachStatusLineNotificationHandlers() {
        guard let appState = notificationAppState, let tab else { return }
        statusLineMonitor?.onClaudeHookAttention = { [weak self] event in
            Task { @MainActor in
                guard let pane = self else { return }
                guard event.source != .ohMyPiStop || SettingsPersistence.isOhMyPiStopNotificationEnabled() else {
                    return
                }
                pane.terminalController?.onAttention?(event)
            }
        }
        statusLineMonitor?.onClaudeStopped = { [weak appState, weak tab, weak self] in
            Task { @MainActor in
                guard let appState, let tab, let pane = self else { return }
                guard SettingsPersistence.isClaudeStopNotificationEnabled() else { return }
                appState.addNotification(
                    paneID: pane.id,
                    paneName: pane.name,
                    tabID: tab.id,
                    tabName: tab.name,
                    isPriority: pane.isPriority,
                    event: .claudeStop
                )
            }
        }
        statusLineMonitor?.onOpencodeStopped = { [weak appState, weak tab, weak self] in
            Task { @MainActor in
                guard let appState, let tab, let pane = self else { return }
                guard SettingsPersistence.isOpencodeStopNotificationEnabled() else { return }
                appState.addNotification(
                    paneID: pane.id,
                    paneName: pane.name,
                    tabID: tab.id,
                    tabName: tab.name,
                    isPriority: pane.isPriority,
                    event: .opencodeStop
                )
            }
        }
        statusLineMonitor?.onOpencodeSessionBound = { [weak appState, weak self] id in
            Task { @MainActor in
                self?.opencodeRaceLossRestarted = false
                self?.opencodeSessionID = id
                if let appState { SessionPersistence.save(appState: appState) }
            }
        }
        statusLineMonitor?.onOpencodePermissionReplied = { [weak appState, weak self] in
            Task { @MainActor in
                guard let appState, let pane = self else { return }
                appState.clearNotification(paneID: pane.id, kind: .opencodePermissionRequest)
            }
        }
        statusLineMonitor?.onOpencodePortRaceLost = { [weak self] in
            Task { @MainActor in
                guard let pane = self, let tab = pane.tab, !pane.opencodeRaceLossRestarted else { return }
                pane.opencodeRaceLossRestarted = true
                tab.restartPane(pane, appSettings: pane.appSettings)
            }
        }
        statusLineMonitor?.onOhMyPiSessionBound = { [weak appState, weak self] id in
            Task { @MainActor in
                guard let pane = self, pane.ohMyPiSessionID != id else { return }
                pane.ohMyPiSessionID = id
                if let appState { SessionPersistence.save(appState: appState) }
            }
        }
        statusLineMonitor?.onOhMyPiAttentionResolved = { [weak appState, weak self] source in
            Task { @MainActor in
                guard let appState, let pane = self else { return }
                switch source {
                case .ohMyPiPermissionRequest:
                    appState.clearNotification(paneID: pane.id, kind: .ohMyPiPermissionRequest)
                case .ohMyPiInputRequest:
                    appState.clearNotification(paneID: pane.id, kind: .ohMyPiInputRequest)
                default:
                    break
                }
            }
        }
        statusLineMonitor?.onPRMerged = { [weak appState, weak tab, weak self] prNumber, prTitle in
            Task { @MainActor in
                guard let appState, let tab, let pane = self else { return }
                appState.addPRMergedNotification(
                    paneID: pane.id,
                    paneName: pane.name,
                    tabID: tab.id,
                    tabName: tab.name,
                    prNumber: prNumber,
                    prTitle: prTitle
                )
            }
        }
        statusLineMonitor?.onPRClosed = { [weak appState, weak tab, weak self] prNumber, prTitle in
            Task { @MainActor in
                guard let appState, let tab, let pane = self else { return }
                appState.addPRClosedNotification(
                    paneID: pane.id,
                    paneName: pane.name,
                    tabID: tab.id,
                    tabName: tab.name,
                    prNumber: prNumber,
                    prTitle: prTitle
                )
            }
        }
        statusLineMonitor?.onPRReopened = { [weak appState, weak self] in
            Task { @MainActor in
                guard let appState, let pane = self else { return }
                appState.clearPRMergedNotification(paneID: pane.id)
                appState.clearPRClosedNotification(paneID: pane.id)
            }
        }
    }
}
