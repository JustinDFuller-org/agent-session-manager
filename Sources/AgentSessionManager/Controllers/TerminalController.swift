import AppKit
import Foundation
import SwiftTerm

final class BellCapturingTerminalView: LocalProcessTerminalView {
    var onAttention: ((PaneAttentionEvent) -> Void)?
    var onUserInput: (() -> Void)?
    /// Set from `Tab.addPane` for telemetry (read from PTY threads; best-effort for debugging).
    var telemetryTabName: String = ""
    var telemetryTabUUID: UUID?
    var telemetryPaneName: String = ""
    var telemetryPaneUUID: UUID?
    private var osc777HookInstalled = false
    private var keyEventMonitor: Any?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        // SwiftTerm clears the text selection on every PTY chunk and every newline
        // while mouse reporting is on, so it never survives streaming output.
        // Scroll-wheel forwarding to alt-buffer TUIs is handled separately in
        // App.swift based on `terminal.mouseMode`, so this only gives up in-TUI
        // mouse clicks/drags.
        allowMouseReporting = false
        installOsc777AttentionHookIfNeeded()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        allowMouseReporting = false
        installOsc777AttentionHookIfNeeded()
    }

    /// Reject transient tiny frames from SwiftUI layout passes that would corrupt
    /// scrollback by resizing the terminal to 1 column. SwiftUI's LazyVGrid can
    /// produce intermediate non-zero but tiny frames when panes are added/removed.
    override func setFrameSize(_ newSize: NSSize) {
        let currentCols = terminal?.cols ?? 0
        guard currentCols >= 2 else {
            super.setFrameSize(newSize)
            return
        }
        let currentWidth = frame.width
        guard currentWidth > 0 else {
            super.setFrameSize(newSize)
            return
        }
        let cellWidth = currentWidth / CGFloat(currentCols)
        let proposedCols = Int(newSize.width / cellWidth)
        if proposedCols < 2 {
            return
        }
        super.setFrameSize(newSize)
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil, keyEventMonitor == nil {
            keyEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self, self.window?.firstResponder === self else { return event }
                self.onUserInput?()
                return event
            }
        } else if window == nil, let monitor = keyEventMonitor {
            NSEvent.removeMonitor(monitor)
            keyEventMonitor = nil
        }
    }

    deinit {
        if let monitor = keyEventMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    override func bell(source: Terminal) {
        super.bell(source: source)
        let event = PaneAttentionEvent.rawBell
        onAttention?(event)
        Task { @MainActor in
            var attrs: [String: String] = [
                "source": "bell",
                "reason": event.reason,
                "pane.name": self.telemetryPaneName,
                "tab.name": self.telemetryTabName,
            ]
            if let id = self.telemetryPaneUUID { attrs["pane.id"] = id.uuidString }
            if let id = self.telemetryTabUUID { attrs["tab.id"] = id.uuidString }
            TracingService.shared.record("terminal.attention.delivered", attributes: attrs)
        }
    }

    /// Hooks OSC 777 (`ESC]777;notify;title;body BEL`) into the same path as ``bell(source:)``.
    /// SwiftTerm invokes this via `TerminalDelegate.notify`, but default protocol conformance is not
    /// overridden by subclasses, so we register a parser handler (see `Terminal.registerOscHandler`).
    func installOsc777AttentionHookIfNeeded() {
        guard !osc777HookInstalled else { return }
        osc777HookInstalled = true
        getTerminal().registerOscHandler(code: 777) { [weak self] data in
            guard let self else { return }
            guard let text = String(bytes: data, encoding: .utf8) else { return }
            guard let event = PaneAttentionEvent.osc777(text) else { return }
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.onAttention?(event)
                Task { @MainActor in
                    var attrs: [String: String] = [
                        "source": "osc777",
                        "reason": event.reason,
                        "pane.name": self.telemetryPaneName,
                        "tab.name": self.telemetryTabName,
                    ]
                    if let id = self.telemetryPaneUUID { attrs["pane.id"] = id.uuidString }
                    if let id = self.telemetryTabUUID { attrs["tab.id"] = id.uuidString }
                    TracingService.shared.record("terminal.attention.delivered", attributes: attrs)
                }
            }
        }
    }
}

@Observable
@MainActor
final class TerminalController: NSObject {
    let terminalView: BellCapturingTerminalView
    var processState: ProcessState = .idle
    var pendingCommand: String?
    var pendingDirectory: String?
    var pendingEnvironment: [String]?
    var pendingShell: String?
    @ObservationIgnored var onAttention: ((PaneAttentionEvent) -> Void)?

    enum ProcessState: Equatable {
        case idle
        case running(pid: Int32)
        case exited(code: Int32?)
    }

    override init() {
        terminalView = BellCapturingTerminalView(frame: .zero)
        super.init()
        terminalView.processDelegate = self
        terminalView.onAttention = { [weak self] event in self?.onAttention?(event) }
    }

    /// Called by TerminalRepresentable.Coordinator after the view has a non-zero frame.
    func startProcess() {
        let shell = pendingShell ?? ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
        if let cmd = pendingCommand {
            // Args evolution:
            // - Removed -l (login shell) because it causes zsh to source /etc/zprofile,
            //   ~/.zprofile, and shell init scripts which access TCC-protected paths
            //   (iCloud Drive, Music, etc.) and trigger macOS permission dialogs.
            // - Do NOT use -f (fast start). It skips ~/.zshrc, which prevents tools
            //   like nvm (node), homebrew, and other PATH-managing shell init from
            //   running. This breaks CLI tools like codex and cursor that rely on the
            //   user's shell environment for PATH resolution.
            // - HOME is NOT scoped — Claude Code needs real HOME for ~/.claude/ auth.
            //   Remaining TCC prompts are one-time decisions from Claude's startup
            //   path scanning. See documentation/features/panes.md.
            //
            // Environment is sanitized at the last moment before starting the process so that
            // GUI launches (e.g., opening the app from the DMG) get the same TERM/COLORTERM/LANG
            // and PATH baseline that terminal-launched runs inherit from the parent shell.
            let args = ["-i", "-c", cmd]
            let env = ProcessEnvironment.sanitize(pendingEnvironment ?? [])
            let cwd = pendingDirectory
            terminalView.startProcess(
                executable: shell,
                args: args,
                environment: env,
                currentDirectory: cwd
            )
            let tracePaneName = terminalView.telemetryPaneName
            let traceTabName = terminalView.telemetryTabName
            let tracePaneUUID = terminalView.telemetryPaneUUID
            let traceTabUUID = terminalView.telemetryTabUUID
            Task(priority: .utility) { @MainActor in
                var attrs: [String: String] = [
                    "executable": shell,
                    "args": args.joined(separator: " "),
                    "working_directory": cwd ?? "",
                    "pane.name": tracePaneName,
                    "tab.name": traceTabName,
                ]
                if let id = tracePaneUUID { attrs["pane.id"] = id.uuidString }
                if let id = traceTabUUID { attrs["tab.id"] = id.uuidString }
                TracingService.shared.record("terminal.process.started", attributes: attrs)
            }
        } else {
            let env = ProcessEnvironment.sanitize(pendingEnvironment ?? [])
            let cwd = pendingDirectory
            terminalView.startProcess(
                executable: shell,
                environment: env,
                currentDirectory: cwd
            )
            let tracePaneName = terminalView.telemetryPaneName
            let traceTabName = terminalView.telemetryTabName
            let tracePaneUUID = terminalView.telemetryPaneUUID
            let traceTabUUID = terminalView.telemetryTabUUID
            Task(priority: .utility) { @MainActor in
                var attrs: [String: String] = [
                    "executable": shell,
                    "args": "",
                    "working_directory": cwd ?? "",
                    "pane.name": tracePaneName,
                    "tab.name": traceTabName,
                ]
                if let id = tracePaneUUID { attrs["pane.id"] = id.uuidString }
                if let id = traceTabUUID { attrs["tab.id"] = id.uuidString }
                TracingService.shared.record("terminal.process.started", attributes: attrs)
            }
        }
        let pid = terminalView.process.shellPid
        if pid > 0 {
            processState = .running(pid: pid)
        }
    }

    var terminalContent: String {
        let terminal = terminalView.terminal
        guard let terminal, terminal.rows > 0, terminal.cols > 0 else { return "" }
        var lines: [String] = []
        for row in 0..<terminal.rows {
            var chars: [Character] = []
            for col in 0..<terminal.cols {
                if let ch = terminal.getCharacter(col: col, row: row) {
                    let safeChar: Character = ch.unicodeScalars.first?.value == 0 ? " " : ch
                    chars.append(safeChar)
                }
            }
            let line = String(chars).replacingOccurrences(of: "\\s+$", with: "", options: .regularExpression)
            lines.append(line)
        }
        while let last = lines.last, last.isEmpty {
            lines.removeLast()
        }
        return lines.joined(separator: "\n")
    }

    func focusTerminal() {
        terminalView.window?.makeFirstResponder(terminalView)
    }

    func terminate() {
        terminalView.terminate()
    }
}

extension TerminalController: LocalProcessTerminalViewDelegate {
    nonisolated func processTerminated(source: TerminalView, exitCode: Int32?) {
        Task { @MainActor in
            self.processState = .exited(code: exitCode)
            var attrs: [String: String] = [
                "exit_code": exitCode.map(String.init) ?? "nil",
                "pane.name": self.terminalView.telemetryPaneName,
                "tab.name": self.terminalView.telemetryTabName,
            ]
            if let id = self.terminalView.telemetryPaneUUID { attrs["pane.id"] = id.uuidString }
            if let id = self.terminalView.telemetryTabUUID { attrs["tab.id"] = id.uuidString }
            TracingService.shared.record("terminal.process.exited", attributes: attrs)
        }
    }

    nonisolated func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {}
    nonisolated func setTerminalTitle(source: LocalProcessTerminalView, title: String) {}
    nonisolated func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}
}
