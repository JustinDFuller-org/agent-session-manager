import AppKit
import SwiftTerm

final class BellCapturingTerminalView: LocalProcessTerminalView {
    var onBell: (() -> Void)?

    override func bell(source: Terminal) {
        super.bell(source: source)
        DispatchQueue.main.async { [weak self] in
            self?.onBell?()
        }
    }
}

@MainActor
final class TerminalController: NSObject {
    let terminalView: BellCapturingTerminalView
    private(set) var processState: ProcessState = .idle
    var pendingCommand: String? = nil
    var pendingDirectory: String? = nil
    var pendingEnvironment: [String]? = nil
    var onBell: (() -> Void)? = nil

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
    }

    /// Called by TerminalRepresentable.Coordinator after the view has a non-zero frame.
    func startProcess() {
        let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
        if let cmd = pendingCommand {
            // Args evolution:
            // - Removed -l (login shell) because it causes zsh to source /etc/zprofile,
            //   ~/.zprofile, and shell init scripts which access TCC-protected paths
            //   (iCloud Drive, Music, etc.) and trigger macOS permission dialogs.
            // - Added -f (fast start) to skip loading ~/.zshrc, /etc/zshenv, and all
            //   other startup files. The -i flag is kept for interactive PTY behavior.
            // - HOME is NOT scoped — Claude Code needs real HOME for ~/.claude/ auth.
            //   Remaining TCC prompts are one-time decisions from Claude's startup
            //   path scanning. See documentation/features/panes.md.
            let args = ["-f", "-i", "-c", cmd]
            DebugLogger.shared.logProcessStart(
                executable: shell,
                args: args,
                environment: pendingEnvironment,
                currentDirectory: pendingDirectory
            )
            terminalView.startProcess(
                executable: shell,
                args: args,
                environment: pendingEnvironment,
                currentDirectory: pendingDirectory
            )
        } else {
            DebugLogger.shared.logProcessStart(
                executable: shell,
                args: [],
                environment: pendingEnvironment,
                currentDirectory: pendingDirectory
            )
            terminalView.startProcess(
                executable: shell,
                environment: pendingEnvironment,
                currentDirectory: pendingDirectory
            )
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
                    chars.append(ch)
                } else {
                    chars.append(" ")
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

    func terminate() {
        terminalView.terminate()
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
