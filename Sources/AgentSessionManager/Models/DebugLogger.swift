import Foundation
import Observation
#if canImport(AppKit)
import AppKit
#endif

@Observable
@MainActor
final class DebugLogger {
    static let shared = DebugLogger()

    /// Hard cap on stored log lines to bound memory; oldest entries are discarded first.
    static let telemetryEntryCap = 1000

    private let maxMessageLength = 4000

    struct Entry: Identifiable, Codable {
        let id: UUID
        let timestamp: Date
        let message: String
    }

    var isEnabled = false
    var entries: [Entry] = []
    /// Entries removed because of `telemetryEntryCap` (not including lines removed by Clear).
    private(set) var totalEntriesDropped = 0

    func log(_ message: String) {
        guard isEnabled else { return }
        let capped = message.count > maxMessageLength
            ? String(message.prefix(maxMessageLength)) + "…"
            : message
        appendEntry(Entry(id: UUID(), timestamp: Date(), message: capped))
    }

    func clear() {
        entries = []
        totalEntriesDropped = 0
    }

    private func appendEntry(_ entry: Entry) {
        entries.append(entry)
        var removed = 0
        while entries.count > Self.telemetryEntryCap {
            entries.removeFirst()
            removed += 1
        }
        guard removed > 0 else { return }
        let bucketBefore = totalEntriesDropped / 50
        totalEntriesDropped += removed
        let bucketAfter = totalEntriesDropped / 50
        guard bucketAfter > bucketBefore else { return }
        let summary = Entry(
            id: UUID(),
            timestamp: Date(),
            message: "[telemetry] ring buffer dropped older entries (total dropped: \(totalEntriesDropped), cap=\(Self.telemetryEntryCap))"
        )
        entries.append(summary)
        while entries.count > Self.telemetryEntryCap {
            entries.removeFirst()
            totalEntriesDropped += 1
        }
    }

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
        let capped = trimmed.count > 4000 ? String(trimmed.prefix(4000)) + "…" : trimmed
        log("\(header)\n\(capped)")
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

    func buildReportText(maxBodyLength: Int? = nil) -> String {
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

        let footer = "```"
        var includedCount = 0

        for entry in entries.reversed() {
            df.dateFormat = "HH:mm:ss.SSS"
            var msg = entry.message.count > 8000 ? String(entry.message.prefix(8000)) + "…" : entry.message
            let timestampPrefix = "[\(df.string(from: entry.timestamp))] "

            if let maxLen = maxBodyLength, includedCount > 0 {
                let prospective = (lines + [timestampPrefix + msg, "", footer]).joined(separator: "\n")
                if prospective.count > maxLen {
                    break
                }
            }

            if let maxLen = maxBodyLength, includedCount == 0 {
                let overhead = (lines + [timestampPrefix, "", footer]).joined(separator: "\n").count
                let maxMsgLen = maxLen - overhead
                if maxMsgLen <= 0 {
                    msg = "(entry omitted — report body too large for URL)"
                } else if msg.count > maxMsgLen {
                    msg = String(msg.prefix(maxMsgLen)) + "…"
                }
            }

            lines.append(timestampPrefix + msg)
            lines.append("")
            includedCount += 1
        }

        if let _ = maxBodyLength, includedCount < entries.count {
            lines.append("...showing \(includedCount) of \(entries.count) most recent entries")
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
