import AppKit
import Foundation
import SwiftTerm

final class BellCapturingTerminalView: LocalProcessTerminalView {
    var onBell: (() -> Void)?
    /// Set from `Tab.addPane` for telemetry (read from PTY threads; best-effort for debugging).
    var telemetryTabName: String = ""
    var telemetryPaneName: String = ""
    var telemetryPaneUUID: UUID?
    private var osc777HookInstalled = false

    private let terminalStreamDebounceLock = NSLock()
    private var terminalStreamDebounceWork: DispatchWorkItem?
    /// Fingerprint of last streamed screen text; only read/written on the main actor.
    private var lastTerminalStreamFingerprint: Int?

    override func dataReceived(slice: ArraySlice<UInt8>) {
        super.dataReceived(slice: slice)
        scheduleDebouncedTerminalStreamFlush()
    }

    private func scheduleDebouncedTerminalStreamFlush() {
        terminalStreamDebounceLock.lock()
        terminalStreamDebounceWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            Task { @MainActor in
                self.flushTerminalStreamSnapshotToDebugIfNeeded()
            }
        }
        terminalStreamDebounceWork = work
        terminalStreamDebounceLock.unlock()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: work)
    }

    @MainActor
    private func flushTerminalStreamSnapshotToDebugIfNeeded() {
        guard let paneID = telemetryPaneUUID else { return }
        guard DebugLogger.shared.isTerminalCaptureEnabled(for: paneID) else { return }
        let content = TerminalController.renderedScreenText(from: getTerminal())
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        var hasher = Hasher()
        hasher.combine(content)
        let fingerprint = hasher.finalize()
        if fingerprint == lastTerminalStreamFingerprint { return }
        lastTerminalStreamFingerprint = fingerprint
        DebugLogger.shared.logTerminalContent(
            paneName: telemetryPaneName.isEmpty ? "?" : telemetryPaneName,
            content: content,
            tabName: telemetryTabName.isEmpty ? "?" : telemetryTabName,
            paneID: paneID,
            kind: DebugLogger.TerminalContentLogKind.stream
        )
    }

    override func bell(source: Terminal) {
        super.bell(source: source)
        let pane = telemetryPaneName.isEmpty ? "?" : telemetryPaneName
        let msg = "[bell] SwiftTerm bell() pane=\(pane)"
        deliverAttentionToHost(logMessage: msg)
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
            let parts = text.components(separatedBy: ";")
            guard parts.count >= 3, parts[0] == "notify" else { return }
            let title = parts[1]
            let body = parts[2...].joined(separator: ";")
            let label = self.telemetryPaneName.isEmpty ? "?" : self.telemetryPaneName
            let safeTitle = String(title.prefix(200)).replacingOccurrences(of: "\n", with: " ")
            let safeBody = String(body.prefix(500)).replacingOccurrences(of: "\n", with: " ")
            let msg = "[bell] SwiftTerm notify(OSC 777) pane=\(label) title=\(safeTitle) body=\(safeBody)"
            self.deliverAttentionToHost(logMessage: msg)
        }
    }

    private func deliverAttentionToHost(logMessage: String) {
        let paneId = telemetryPaneUUID
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let debug = DebugLogger.shared
            if let id = paneId {
                if debug.acceptsPaneDiagnostics(paneID: id) {
                    debug.log(
                        logMessage,
                        paneID: id,
                        tabName: self.telemetryTabName,
                        paneName: self.telemetryPaneName
                    )
                }
            } else if debug.isEnabled {
                debug.log(logMessage)
            }
            self.onBell?()
        }
    }
}

@MainActor
final class TerminalController: NSObject {
    let terminalView: BellCapturingTerminalView
    private(set) var processState: ProcessState = .idle
    var pendingCommand: String?
    var pendingDirectory: String?
    var pendingEnvironment: [String]?
    var onBell: (() -> Void)?

    enum ProcessState: Equatable {
        case idle
        case running(pid: Int32)
        case exited(code: Int32?)
    }

    override init() {
        terminalView = BellCapturingTerminalView(frame: .zero)
        super.init()
        terminalView.processDelegate = self
        terminalView.onBell = { [weak self] in self?.onBell?() }
        terminalView.installOsc777AttentionHookIfNeeded()
    }

    /// Called by TerminalRepresentable.Coordinator after the view has a non-zero frame.
    func startProcess() {
        let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
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
            let args = ["-i", "-c", cmd]
            let tracePane = terminalView.telemetryPaneUUID
            let env = pendingEnvironment
            let cwd = pendingDirectory
            terminalView.startProcess(
                executable: shell,
                args: args,
                environment: env,
                currentDirectory: cwd
            )
            Self.scheduleDeferredProcessStartLog(
                executable: shell,
                args: args,
                environment: env,
                currentDirectory: cwd,
                paneID: tracePane,
                tabName: terminalView.telemetryTabName,
                paneName: terminalView.telemetryPaneName
            )
        } else {
            let tracePane = terminalView.telemetryPaneUUID
            let env = pendingEnvironment
            let cwd = pendingDirectory
            terminalView.startProcess(
                executable: shell,
                environment: env,
                currentDirectory: cwd
            )
            Self.scheduleDeferredProcessStartLog(
                executable: shell,
                args: [],
                environment: env,
                currentDirectory: cwd,
                paneID: tracePane,
                tabName: terminalView.telemetryTabName,
                paneName: terminalView.telemetryPaneName
            )
        }
        let pid = terminalView.process.shellPid
        if pid > 0 {
            processState = .running(pid: pid)
        }
    }

    var terminalContent: String {
        Self.renderedScreenText(from: terminalView.terminal)
    }

    /// On-screen terminal text for the current viewport (`Terminal.getCharacter`), excluding NULs and trailing blank lines.
    static func renderedScreenText(from terminal: Terminal?) -> String {
        guard let terminal, terminal.rows > 0, terminal.cols > 0 else { return "" }
        var lines: [String] = []
        for row in 0..<terminal.rows {
            var chars: [Character] = []
            for col in 0..<terminal.cols {
                if let ch = terminal.getCharacter(col: col, row: row),
                    ch.unicodeScalars.first?.value != 0
                {
                    chars.append(ch)
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

    /// Builds large log lines off the critical path so the PTY can start before telemetry work runs.
    private static func scheduleDeferredProcessStartLog(
        executable: String,
        args: [String],
        environment: [String]?,
        currentDirectory: String?,
        paneID: UUID?,
        tabName: String,
        paneName: String
    ) {
        Task(priority: .utility) { @MainActor in
            DebugLogger.shared.logProcessStart(
                executable: executable,
                args: args,
                environment: environment,
                currentDirectory: currentDirectory,
                paneID: paneID,
                tabName: tabName.isEmpty ? nil : tabName,
                paneName: paneName.isEmpty ? nil : paneName
            )
        }
    }
}

extension TerminalController: LocalProcessTerminalViewDelegate {
    nonisolated func processTerminated(source: TerminalView, exitCode: Int32?) {
        Task { @MainActor in
            self.processState = .exited(code: exitCode)
        }
    }

    nonisolated func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {}
    nonisolated func setTerminalTitle(source: LocalProcessTerminalView, title: String) {}
    nonisolated func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}
}
