import Foundation
import Observation
import AppKit

@Observable
@MainActor
final class DebugLogger {
    static let shared = DebugLogger()

    /// Hard cap on stored log lines to bound memory; oldest entries are discarded first.
    static let telemetryEntryCap = 1000

    /// Separate cap for bell / notification / banner diagnostics — not evicted by the main ring buffer.
    static let notificationDiagnosticCap = 200

    /// Beyond this, process-start env logging lists only the first N entries (MainActor + privacy).
    static let processStartEnvSampleLineCap = 12

    private let maxMessageLength = 4000
    private let processStartEnvValueCap = 96

    struct Entry: Identifiable, Codable {
        let id: UUID
        let timestamp: Date
        let message: String
    }

    var isEnabled = false
    /// In-memory only; enables pane-tagged telemetry when global debug logging is off.
    private(set) var tracedPaneIDs: Set<UUID> = []
    var entries: [Entry] = []
    /// Bell / notify / banner lines pinned so they survive main-buffer eviction (debugging notifications).
    private(set) var notificationDiagnosticEntries: [Entry] = []
    /// Entries removed because of `telemetryEntryCap` (not including lines removed by Clear).
    private(set) var totalEntriesDropped = 0

    var isDebugLogButtonVisible: Bool { isEnabled || !tracedPaneIDs.isEmpty }

    private func acceptsPaneTaggedLogging(paneID: UUID) -> Bool {
        isEnabled || tracedPaneIDs.contains(paneID)
    }

    func setPaneTraceEnabled(_ paneID: UUID, _ enabled: Bool) {
        if enabled {
            tracedPaneIDs.insert(paneID)
        } else {
            tracedPaneIDs.remove(paneID)
        }
        Self.postTracingChangedNotification()
    }

    func removeTracedPane(_ paneID: UUID) {
        tracedPaneIDs.remove(paneID)
        Self.postTracingChangedNotification()
    }

    /// Resets per-pane tracing (e.g. tests). Does not clear log entries.
    func removeAllTracedPanes() {
        tracedPaneIDs.removeAll()
        Self.postTracingChangedNotification()
    }

    private static func postTracingChangedNotification() {
        NotificationCenter.default.post(name: .agentSessionManagerDebugTracingChanged, object: nil)
    }

    func log(_ message: String) {
        guard isEnabled else { return }
        recordMessage(message)
    }

    func log(_ message: String, paneID: UUID) {
        guard acceptsPaneTaggedLogging(paneID: paneID) else { return }
        recordMessage(message)
    }

    private func recordMessage(_ message: String) {
        let capped = message.count > maxMessageLength
            ? String(message.prefix(maxMessageLength)) + "…"
            : message
        let entry = Entry(id: UUID(), timestamp: Date(), message: capped)
        if Self.messageTriggersNotificationDiagnosticPin(capped) {
            appendNotificationDiagnosticEntry(entry)
        }
        appendEntry(entry)
    }

    private static func messageTriggersNotificationDiagnosticPin(_ message: String) -> Bool {
        message.contains("[bell]")
            || message.contains("[notify]")
            || message.contains("[banner]")
            || message.contains("[telemetry] ring buffer")
    }

    private func appendNotificationDiagnosticEntry(_ entry: Entry) {
        notificationDiagnosticEntries.append(entry)
        while notificationDiagnosticEntries.count > Self.notificationDiagnosticCap {
            notificationDiagnosticEntries.removeFirst()
        }
    }

    /// Redacts environment-style `KEY=value` lines when the key suggests credentials (copy / GitHub issue body).
    static func redactSensitiveEnvStyleLines(_ text: String) -> String {
        text.split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
            .map { redactSensitiveEnvStyleLine($0) }
            .joined(separator: "\n")
    }

    static func redactSensitiveEnvStyleLine(_ line: String) -> String {
        guard let eq = line.firstIndex(of: "="), eq > line.startIndex else { return line }
        let keyPart = line[..<eq].trimmingCharacters(in: .whitespaces)
        guard !keyPart.isEmpty else { return line }
        let valueStart = line.index(after: eq)
        guard valueStart < line.endIndex else { return line }

        let keyUpper = String(keyPart).uppercased()
        for token in sensitiveEnvKeySubstrings {
            if keyUpper.contains(token) {
                return "\(keyPart)=<redacted>"
            }
        }
        return line
    }

    private static let sensitiveEnvKeySubstrings: [String] = [
        "TOKEN", "SECRET", "PASSWORD", "API_KEY", "APIKEY",
        "PRIVATE_KEY", "CREDENTIAL", "BEARER", "AUTHORIZATION",
        "ANTHROPIC", "JIRA", "DATADOG", "DRONE", "VAULT", "ARTIFACTORY",
        "AWS_", "GCLOUD", "GOOGLE_APPLICATION", "SSH_",
    ]

    func clear() {
        entries = []
        notificationDiagnosticEntries = []
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

    func logProcessStart(
        executable: String,
        args: [String],
        environment: [String]?,
        currentDirectory: String?,
        paneID: UUID? = nil
    ) {
        if let paneID {
            guard acceptsPaneTaggedLogging(paneID: paneID) else { return }
        } else {
            guard isEnabled else { return }
        }
        var lines: [String] = []
        lines.append("── Process Start ──")
        lines.append("executable: \(executable)")
        lines.append("args: \(args.joined(separator: " "))")
        if let cwd = currentDirectory {
            lines.append("cwd: \(cwd)")
        }
        if let env = environment {
            lines.append("environment (\(env.count) vars, showing first \(min(env.count, Self.processStartEnvSampleLineCap))):")
            for (index, pair) in env.enumerated() where index < Self.processStartEnvSampleLineCap {
                let parts = pair.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
                let key = parts.first.map(String.init) ?? ""
                let value = parts.count > 1 ? String(parts[1]) : ""
                let truncated = value.count > processStartEnvValueCap
                    ? String(value.prefix(processStartEnvValueCap)) + "…"
                    : value
                lines.append("  \(key)=\(truncated)")
            }
            if env.count > Self.processStartEnvSampleLineCap {
                lines.append("  … \(env.count - Self.processStartEnvSampleLineCap) more vars omitted (disable Debug Logging or use Capture Terminal to reduce overhead)")
            }
        }
        recordMessage(lines.joined(separator: "\n"))
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

    func logTerminalContent(paneName: String, content: String, paneID: UUID? = nil) {
        if let paneID {
            guard acceptsPaneTaggedLogging(paneID: paneID) else { return }
        } else {
            guard isEnabled else { return }
        }
        let header = "── Terminal Content: \(paneName) ──"
        let trimmed = content.hasSuffix("\n") ? String(content.dropLast()) : content
        let capped = trimmed.count > 4000 ? String(trimmed.prefix(4000)) + "…" : trimmed
        recordMessage("\(header)\n\(capped)")
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

        if !notificationDiagnosticEntries.isEmpty {
            lines.append("### Pinned notification diagnostics")
            lines.append("(Bell, notify, and banner log lines; kept when the main telemetry ring drops older entries.)")
            lines.append("```")
            df.dateFormat = "HH:mm:ss.SSS"
            for entry in notificationDiagnosticEntries {
                let raw = entry.message.count > 8000 ? String(entry.message.prefix(8000)) + "…" : entry.message
                let msg = Self.redactSensitiveEnvStyleLines(raw)
                lines.append("[\(df.string(from: entry.timestamp))] \(msg)")
                lines.append("")
            }
            lines.append("```")
            lines.append("")
        }

        lines.append("### Debug Log")
        lines.append("Environment-style secrets in `KEY=value` lines are redacted (`<redacted>`).")
        lines.append("```")

        let footer = "```"
        var includedCount = 0

        for entry in entries.reversed() {
            df.dateFormat = "HH:mm:ss.SSS"
            let raw = entry.message.count > 8000 ? String(entry.message.prefix(8000)) + "…" : entry.message
            var msg = Self.redactSensitiveEnvStyleLines(raw)
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

    static func openBugReport() {
        let title = "[Bug] "
        guard let encodedTitle = title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
        else { return }

        let maxURLLength = 7800
        let baseURL = "https://github.com/JustinDFuller/agent-session-manager/issues/new?title=\(encodedTitle)&body="
        var maxRawBody = maxURLLength - baseURL.count

        for _ in 0..<3 {
            let body = shared.buildReportText(maxBodyLength: maxRawBody)
            guard let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return }

            let urlString = baseURL + encodedBody
            if urlString.count <= maxURLLength {
                guard let url = URL(string: urlString) else { return }
                NSWorkspace.shared.open(url)
                return
            }
            maxRawBody = maxRawBody / 2
        }
    }
}

extension Notification.Name {
    /// Posted when per-pane debug tracing membership changes (ladybug visibility).
    static let agentSessionManagerDebugTracingChanged = Notification.Name("agentSessionManagerDebugTracingChanged")
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
