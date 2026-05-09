import Foundation
import Observation
import AppKit
import UserNotifications

// MARK: - File sink

/// Serializes UTF-8 trace lines to disk and truncates from the beginning when over max byte size.
final class DebugFileTraceSink: @unchecked Sendable {
    static let shared = DebugFileTraceSink()

    private let queue = DispatchQueue(label: "com.justinfuller.agent-session-manager.debug-trace-file", qos: .utility)

    func append(line: String, fileURL: URL, maxBytes: Int) {
        guard !line.isEmpty else { return }
        let payload = Data(line.utf8) + Data([0x0A])
        queue.async {
            Self.writeSync(payload: payload, fileURL: fileURL, maxBytes: maxBytes)
        }
    }

    func truncateFile(at fileURL: URL) {
        queue.async {
            try? FileManager.default.removeItem(at: fileURL)
        }
    }

    /// Waits until queued writes finish (unit tests only).
    func barrierForTesting() {
        queue.sync {}
    }

    private static func writeSync(payload: Data, fileURL: URL, maxBytes: Int) {
        let directory = fileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        if !FileManager.default.fileExists(atPath: fileURL.path) {
            FileManager.default.createFile(atPath: fileURL.path, contents: nil)
        }
        guard let handle = try? FileHandle(forWritingTo: fileURL) else { return }
        defer { try? handle.close() }
        do {
            try handle.seekToEnd()
            try handle.write(contentsOf: payload)
        } catch {
            return
        }
        trimStartOfFileIfNeeded(at: fileURL, maxBytes: maxBytes)
    }

    /// Drops the oldest log bytes so the file stays at or below `maxBytes`, cutting on a newline boundary when possible.
    private static func trimStartOfFileIfNeeded(at url: URL, maxBytes: Int) {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let sizeNum = attrs[.size] as? NSNumber
        else { return }
        let size = sizeNum.intValue
        guard size > maxBytes else { return }
        guard let data = try? Data(contentsOf: url), !data.isEmpty else { return }

        let targetKeep = maxBytes - 512 // leave room for truncation banner
        let dropCount = max(0, data.count - targetKeep)
        var cut = dropCount
        while cut < data.count, data[cut] != UInt8(ascii: "\n") {
            cut += 1
        }
        if cut < data.count { cut += 1 }

        var newData = Data("--- [truncated older log entries] ---\n".utf8)
        if cut < data.count {
            newData.append(data[cut...])
        }
        try? newData.write(to: url, options: .atomic)
    }
}

// MARK: - Logger

@Observable
@MainActor
final class DebugLogger {
    static let shared = DebugLogger()

    /// Beyond this, process-start env logging lists only the first N entries (MainActor + privacy).
    static let processStartEnvSampleLineCap = 12

    private let maxMessageLineLength = 4000
    private let processStartEnvValueCap = 96

    private let timestampFormatter: DateFormatter = {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = TimeZone.current
        df.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return df
    }()

    var isEnabled = false
    /// In-memory only; enables pane-tagged telemetry when global debug logging is off.
    private(set) var tracedPaneIDs: Set<UUID> = []
    /// When global “include terminal” is off, these panes may still write terminal snapshots to the trace file.
    private(set) var tracedPaneTerminalCaptureIDs: Set<UUID> = []

    /// File URL and cap mirror Settings (updated via `syncFromAppSettings`).
    private(set) var traceFileURL: URL = DebugLogger.defaultTraceFileURL()
    private(set) var traceFileMaxBytes: Int = AppSettings.defaultDebugLogMaxFileBytes
    private(set) var includeTerminalContentsGlobally: Bool = false

    var isDebugLogButtonVisible: Bool {
        isEnabled || !tracedPaneIDs.isEmpty || !tracedPaneTerminalCaptureIDs.isEmpty
    }

    static func defaultTraceFileURL() -> URL {
        let config = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = config.appending(path: PersistenceHelpers.appSupportSubdirectory)
        return dir.appending(path: "debug-trace.log").standardizedFileURL
    }

    func syncFromAppSettings(_ appSettings: AppSettings) {
        traceFileURL = appSettings.resolvedDebugLogFileURL
        traceFileMaxBytes = max(1_048_576, appSettings.debugLogMaxFileBytes)
        includeTerminalContentsGlobally = appSettings.debugLogIncludeTerminalContents
    }

    private func acceptsPaneTaggedLogging(paneID: UUID) -> Bool {
        isEnabled || tracedPaneIDs.contains(paneID)
    }

    private func shouldWriteTerminalSnapshot(paneID: UUID) -> Bool {
        (isEnabled && includeTerminalContentsGlobally) || tracedPaneTerminalCaptureIDs.contains(paneID)
    }

    /// Event and notification-style pane lines (`[notify]`, `[banner]`, bells, process start) when the pane is fully traced, terminal capture is on for that pane, or global debug is on.
    func acceptsPaneDiagnostics(paneID: UUID) -> Bool {
        acceptsPaneTaggedLogging(paneID: paneID) || shouldWriteTerminalSnapshot(paneID: paneID)
    }

    /// Whether on-screen terminal text may be written for this pane (global debug + include-terminal, or per-pane capture).
    func isTerminalCaptureEnabled(for paneID: UUID) -> Bool {
        shouldWriteTerminalSnapshot(paneID: paneID)
    }

    enum TerminalContentLogKind: Sendable {
        case manualSnapshot
        case stream
    }

    func setPaneTraceEnabled(_ paneID: UUID, _ enabled: Bool) {
        if enabled {
            tracedPaneIDs.insert(paneID)
        } else {
            tracedPaneIDs.remove(paneID)
        }
        Self.postTracingChangedNotification()
    }

    func setPaneTerminalCaptureEnabled(_ paneID: UUID, _ enabled: Bool) {
        if enabled {
            tracedPaneTerminalCaptureIDs.insert(paneID)
        } else {
            tracedPaneTerminalCaptureIDs.remove(paneID)
        }
        Self.postTracingChangedNotification()
    }

    func removeTracedPane(_ paneID: UUID) {
        tracedPaneIDs.remove(paneID)
        tracedPaneTerminalCaptureIDs.remove(paneID)
        Self.postTracingChangedNotification()
    }

    /// Resets per-pane tracing (e.g. tests). Does not truncate the trace file.
    func removeAllTracedPanes() {
        tracedPaneIDs.removeAll()
        tracedPaneTerminalCaptureIDs.removeAll()
        Self.postTracingChangedNotification()
    }

    private static func postTracingChangedNotification() {
        NotificationCenter.default.post(name: .agentSessionManagerDebugTracingChanged, object: nil)
    }

    // MARK: - Public logging API

    func log(_ message: String) {
        guard isEnabled else { return }
        recordMessage(message, paneID: nil, tabName: nil, paneName: nil)
    }

    func log(_ message: String, paneID: UUID, tabName: String = "", paneName: String = "") {
        guard acceptsPaneDiagnostics(paneID: paneID) else { return }
        recordMessage(
            message,
            paneID: paneID,
            tabName: tabName.isEmpty ? nil : tabName,
            paneName: paneName.isEmpty ? nil : paneName
        )
    }

    private func recordMessage(_ message: String, paneID: UUID?, tabName: String?, paneName: String?) {
        let segments = message.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        guard !segments.isEmpty else { return }

        for (index, segment) in segments.enumerated() {
            let capped = segment.count > maxMessageLineLength
                ? String(segment.prefix(maxMessageLineLength)) + "…"
                : segment
            let ts = timestampFormatter.string(from: Date())
            let location: String
            if let tabName, let paneName, !tabName.isEmpty, !paneName.isEmpty {
                location = "[tab: \(tabName)] [pane: \(paneName)]"
            } else if let paneID {
                location = "[pane id: \(paneID.uuidString)]"
            } else {
                location = "[global]"
            }
            let suffix = index > 0 ? " (cont.)" : ""
            let line = "\(ts) \(location)\(suffix) \(capped)"
            DebugFileTraceSink.shared.append(line: line, fileURL: traceFileURL, maxBytes: traceFileMaxBytes)
        }
    }

    func logProcessStart(
        executable: String,
        args: [String],
        environment: [String]?,
        currentDirectory: String?,
        paneID: UUID?,
        tabName: String?,
        paneName: String?
    ) {
        if let paneID {
            guard acceptsPaneDiagnostics(paneID: paneID) else { return }
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
                lines.append("  … \(env.count - Self.processStartEnvSampleLineCap) more vars omitted (reduce trace verbosity in Settings if needed)")
            }
        }
        recordMessage(lines.joined(separator: "\n"), paneID: paneID, tabName: tabName, paneName: paneName)
    }

    func logGitCommand(_ args: [String], cwd: String) {
        guard isEnabled else { return }
        var lines: [String] = []
        lines.append("── Git Command ──")
        lines.append("cwd: \(cwd)")
        lines.append("command: git \(args.joined(separator: " "))")
        recordMessage(lines.joined(separator: "\n"), paneID: nil, tabName: nil, paneName: nil)
    }

    func logSessionRestore(summary: String) {
        guard isEnabled else { return }
        recordMessage("── Session Restore ──\n\(summary)", paneID: nil, tabName: nil, paneName: nil)
    }

    func logWorktreeResolution(userRef: String, result: String) {
        guard isEnabled else { return }
        recordMessage("── Worktree Resolution ──\nref: \(userRef)\nresult: \(result)", paneID: nil, tabName: nil, paneName: nil)
    }

    func logTerminalContent(
        paneName: String,
        content: String,
        tabName: String,
        paneID: UUID,
        kind: TerminalContentLogKind = .manualSnapshot
    ) {
        guard shouldWriteTerminalSnapshot(paneID: paneID) else { return }
        let header: String
        switch kind {
        case .manualSnapshot:
            header = "── Terminal Content: \(paneName) ──"
        case .stream:
            header = "── Terminal stream: \(paneName) ──"
        }
        let trimmed = content.hasSuffix("\n") ? String(content.dropLast()) : content
        let capped = trimmed.count > 4000 ? String(trimmed.prefix(4000)) + "…" : trimmed
        recordMessage("\(header)\n\(capped)", paneID: paneID, tabName: tabName, paneName: paneName)
    }

    func logSystemInfo() {
        guard isEnabled else { return }
        recordMessage(Self.systemInfoBlock(), paneID: nil, tabName: nil, paneName: nil)
    }

    /// UNUserNotificationCenter delivery settings; call when global debug turns on or after changing notification prefs.
    func logNotificationEnvironment(macOSBannerNotificationsEnabled: Bool) {
        guard isEnabled else { return }
        Task(priority: .utility) { @MainActor in
            guard self.isEnabled else { return }
            let center = UNUserNotificationCenter.current()
            let settings = await center.notificationSettings()
            var lines: [String] = []
            lines.append("── Notification Environment ──")
            lines.append("settings.isMacOSBannerNotificationsEnabled: \(macOSBannerNotificationsEnabled)")
            lines.append("UNUserNotificationCenter.authorizationStatus: \(String(describing: settings.authorizationStatus))")
            lines.append("alertSetting: \(String(describing: settings.alertSetting))")
            lines.append("soundSetting: \(String(describing: settings.soundSetting))")
            lines.append("notificationCenterSetting: \(String(describing: settings.notificationCenterSetting))")
            lines.append("lockScreenSetting: \(String(describing: settings.lockScreenSetting))")
            self.recordMessage(lines.joined(separator: "\n"), paneID: nil, tabName: nil, paneName: nil)
        }
    }

    static func systemInfoBlock() -> String {
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
        return lines.joined(separator: "\n")
    }

    /// Removes the on-disk trace file (async). Does not change in-memory trace toggles.
    func clearTraceFile() {
        DebugFileTraceSink.shared.truncateFile(at: traceFileURL)
    }

    /// Truncates the trace file. Preferred name for UI and tests that expect a simple reset of on-disk content.
    func clear() {
        clearTraceFile()
    }

    /// Point trace output at a temp file during unit tests.
    func adoptTraceFileForTesting(url: URL, maxBytes: Int? = nil) {
        traceFileURL = url
        if let maxBytes {
            traceFileMaxBytes = max(1024, maxBytes)
        }
    }

    func flushFileWritesForTesting() {
        DebugFileTraceSink.shared.barrierForTesting()
    }

    // MARK: - Sharing / bug report

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

    /// Short GitHub issue body: system summary + pointer to trace file (no embedded trace).
    func buildBugReportText(traceFilePath: String) -> String {
        var lines: [String] = []
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd HH:mm:ss"
        lines.append("## Bug Report")
        lines.append("Generated: \(df.string(from: Date()))")
        lines.append("")
        lines.append("### Description")
        lines.append("<!-- Describe the issue -->")
        lines.append("")
        lines.append("### System")
        lines.append("```")
        lines.append(Self.redactSensitiveEnvStyleLines(Self.systemInfoBlock()))
        lines.append("```")
        lines.append("")
        lines.append("### Debug trace file")
        lines.append("If **Debug Logging** was enabled (Settings → General), detailed telemetry is appended to:")
        lines.append("")
        lines.append("```")
        lines.append(traceFilePath)
        lines.append("```")
        lines.append("")
        lines.append("Open that file in a text editor, or use **Reveal in Finder** from the debug tracing sheet. Review for secrets before sharing.")
        return lines.joined(separator: "\n")
    }

    static func openBugReport(traceFilePath: String) {
        let title = "[Bug] "
        guard let encodedTitle = title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
        else { return }

        let maxURLLength = 7800
        let baseURL = "https://github.com/JustinDFuller/agent-session-manager/issues/new?title=\(encodedTitle)&body="
        var maxRawBody = maxURLLength - baseURL.count
        let logger = shared

        for _ in 0..<3 {
            let body = logger.buildBugReportText(traceFilePath: traceFilePath)
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
    /// Posted when Claude `Notification` hook integration is toggled (refresh per-pane `--settings` files).
    static let agentSessionManagerClaudeHookAttentionSettingChanged = Notification.Name("agentSessionManagerClaudeHookAttentionSettingChanged")
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
