import AppKit
import SwiftTerm

@MainActor
final class TerminalController: NSObject {
    let terminalView: LocalProcessTerminalView
    private(set) var processState: ProcessState = .idle

    enum ProcessState {
        case idle
        case running(pid: Int32)
        case exited(code: Int32?)
    }

    override init() {
        terminalView = LocalProcessTerminalView(frame: .zero)
        super.init()
        terminalView.processDelegate = self
    }

    func start(executable: String, args: [String]) {
        terminalView.startProcess(executable: executable, args: args)
    }

    func startShellCommand(_ command: String) {
        start(executable: "/bin/bash", args: ["-c", command])
    }

    func terminate() {
        guard case .running(let pid) = processState, pid > 0 else { return }
        kill(pid, SIGTERM)
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

    nonisolated func requestOpenLink(source: TerminalView, link: String, params: [String: String]) {}
}
