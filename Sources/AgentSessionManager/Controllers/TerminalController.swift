import AppKit
import SwiftTerm

@MainActor
final class TerminalController: NSObject {
    let terminalView: LocalProcessTerminalView
    private(set) var processState: ProcessState = .idle
    var pendingCommand: String? = nil
    var pendingDirectory: String? = nil
    var pendingEnvironment: [String]? = nil

    enum ProcessState: Equatable {
        case idle
        case running(pid: Int32)
        case exited(code: Int32?)
    }

    override init() {
        terminalView = LocalProcessTerminalView(frame: .zero)
        super.init()
        terminalView.processDelegate = self
    }

    /// Called by TerminalRepresentable.Coordinator after the view has a non-zero frame.
    func startProcess() {
        if let cmd = pendingCommand {
            terminalView.startProcess(
                executable: "/bin/bash",
                args: ["-c", cmd],
                environment: pendingEnvironment,
                currentDirectory: pendingDirectory
            )
        } else {
            terminalView.startProcess(
                executable: "/bin/bash",
                environment: pendingEnvironment,
                currentDirectory: pendingDirectory
            )
        }
        let pid = terminalView.process.shellPid
        if pid > 0 {
            processState = .running(pid: pid)
        }
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
