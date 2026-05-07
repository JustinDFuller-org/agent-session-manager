import Foundation
import Observation
#if canImport(AppKit)
import AppKit
#endif

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

    func logSystemInfo() {
        guard isEnabled else { return }
        var lines: [String] = []
        lines.append("── System Info ──")
        let osVersion = ProcessInfo.processInfo.operatingSystemVersion
        lines.append("macOS: \(osVersion.majorVersion).\(osVersion.minorVersion).\(osVersion.patchVersion)")
        lines.append("macOS string: \(ProcessInfo.processInfo.operatingSystemVersionString)")
        if let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            lines.append("App version: \(appVersion)")
        }
        if let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
            lines.append("Build: \(build)")
        }
        lines.append("Architecture: \(utsname.machineName)")
        lines.append("Processor count: \(ProcessInfo.processInfo.processorCount)")
        lines.append("Physical memory: \(ProcessInfo.processInfo.physicalMemory / (1024 * 1024 * 1024)) GB")
        log(lines.joined(separator: "\n"))
    }

    func buildReportText() -> String {
        var lines: [String] = []
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd HH:mm:ss"
        lines.append("## Bug Report")
        lines.append("Generated: \(df.string(from: Date()))")
        lines.append("")
        lines.append("### Description")
        lines.append("<!-- Describe the issue -->")
        lines.append("")
        lines.append("### Debug Log")
        lines.append("```")
        for entry in entries {
            df.dateFormat = "HH:mm:ss.SSS"
            lines.append("[\(df.string(from: entry.timestamp))] \(entry.message)")
            lines.append("")
        }
        lines.append("```")
        return lines.joined(separator: "\n")
    }
}

private extension utsname {
    static var machineName: String {
        var sys = utsname()
        uname(&sys)
        return withUnsafePointer(to: &sys.machine) { ptr in
            ptr.withMemoryRebound(to: CChar.self, capacity: Int(_SYS_NAMELEN)) { cstr in
                String(cString: cstr)
            }
        }
    }
}
