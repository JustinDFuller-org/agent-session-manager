import Foundation
import Observation

@Observable
@MainActor
final class DebugLogger {
    static let shared = DebugLogger()

    struct Entry: Identifiable, Codable {
        let id: UUID
        let timestamp: Date
        let message: String
    }

    var isEnabled = false
    var entries: [Entry] = []

    private let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()

    func log(_ message: String) {
        guard isEnabled else { return }
        entries.append(Entry(id: UUID(), timestamp: Date(), message: message))
    }

    func clear() { entries = [] }

    func logProcessStart(executable: String, args: [String], environment: [String]?, currentDirectory: String?) {
        guard isEnabled else { return }
        var lines: [String] = []
        lines.append("── Process Start ──")
        lines.append("executable: \(executable)")
        lines.append("args: \(args.joined(separator: " "))")
        if let cwd = currentDirectory {
            lines.append("cwd: \(cwd)")
        }
        if let env = environment {
            lines.append("environment (\(env.count) vars):")
            for pair in env {
                let parts = pair.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
                let key = parts.first.map(String.init) ?? ""
                let value = parts.count > 1 ? String(parts[1]) : ""
                let truncated = value.count > 200 ? String(value.prefix(200)) + "…" : value
                lines.append("  \(key)=\(truncated)")
            }
        }
        log(lines.joined(separator: "\n"))
    }

    func logGitCommand(_ args: [String], cwd: String) {
        guard isEnabled else { return }
        var lines: [String] = []
        lines.append("── Git Command ──")
        lines.append("cwd: \(cwd)")
        lines.append("command: git \(args.joined(separator: " "))")
        log(lines.joined(separator: "\n"))
    }

    func logSessionRestore(summary: String) {
        guard isEnabled else { return }
        log("── Session Restore ──\n\(summary)")
    }

    func logWorktreeResolution(userRef: String, result: String) {
        guard isEnabled else { return }
        log("── Worktree Resolution ──\nref: \(userRef)\nresult: \(result)")
    }

    func logTerminalContent(paneName: String, content: String) {
        guard isEnabled else { return }
        let header = "── Terminal Content: \(paneName) ──"
        let trimmed = content.hasSuffix("\n") ? String(content.dropLast()) : content
        log("\(header)\n\(trimmed)")
    }
}
