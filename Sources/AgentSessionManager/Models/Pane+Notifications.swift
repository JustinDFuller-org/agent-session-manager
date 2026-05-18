import Foundation

extension Pane {
    /// Hooks the pane’s terminal bell into `AppState` notification UI (sidebar and dots).
    @MainActor
    func wireTerminalBellForNotifications(appState: AppState, tab: Tab, isPriority: Bool) {
        self.isPriority = isPriority
        terminalController?.terminalView.onUserInput = { [weak appState, weak self] in
            Task { @MainActor in
                guard let appState, let pane = self else { return }
                appState.clearNotification(paneID: pane.id)
            }
        }
        terminalController?.onBell = { [weak appState, weak tab, weak self] in
            Task { @MainActor in
                guard let appState, let tab, let pane = self else { return }
                appState.addNotification(
                    paneID: pane.id,
                    paneName: pane.name,
                    tabID: tab.id,
                    tabName: tab.name,
                    isPriority: pane.isPriority
                )
            }
        }
        statusLineMonitor?.onClaudeHookAttention = { [weak self] in
            Task { @MainActor in
                self?.terminalController?.onBell?()
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
    }
}
