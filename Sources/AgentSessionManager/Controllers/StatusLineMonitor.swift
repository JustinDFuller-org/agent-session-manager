import Foundation
import Observation
import AppKit

enum SidebarSide: String, Codable, CaseIterable {
    case left, right

    var displayName: String {
        switch self {
        case .left: return "Left"
        case .right: return "Right"
        }
    }
}

@Observable
@MainActor
final class StatusLineMonitor {
    private(set) var currentData: StatusLineData?

    let filePath: String
    let settingsFilePath: String
    private let workingDirectory: String?
    private let needsSettingsHook: Bool
    private var source: DispatchSourceFileSystemObject?
    private var prTimer: Timer?
    private var prQueryTask: Process?

    init(paneID: UUID, workingDirectory: String? = nil, needsSettingsHook: Bool = true) {
        filePath = NSTemporaryDirectory() + "agent-session-manager-status-\(paneID.uuidString).json"
        settingsFilePath = NSTemporaryDirectory() + "agent-session-manager-settings-\(paneID.uuidString).json"
        self.workingDirectory = workingDirectory
        self.needsSettingsHook = needsSettingsHook
    }

    func start() {
        if needsSettingsHook {
            writeSettingsFile()
        }
        FileManager.default.createFile(atPath: filePath, contents: nil)

        let fd = open(filePath, O_EVTONLY)
        guard fd >= 0 else { return }

        let src = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .extend],
            queue: .global(qos: .utility)
        )
        src.setEventHandler { [weak self, filePath] in
            guard let data = try? Data(contentsOf: URL(filePath: filePath)),
                  let parsed = try? JSONDecoder().decode(StatusLineData.self, from: data)
            else { return }
            Task { @MainActor [weak self] in
                var merged = parsed
                if let existing = self?.currentData?.pr {
                    merged.pr = existing
                }
                self?.currentData = merged
            }
        }
        src.setCancelHandler { close(fd) }
        src.resume()
        source = src

        queryPR()
        prTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.queryPR()
            }
        }
    }

    func stop() {
        source?.cancel()
        source = nil
        prTimer?.invalidate()
        prTimer = nil
        prQueryTask?.terminate()
        prQueryTask = nil
        try? FileManager.default.removeItem(atPath: filePath)
        try? FileManager.default.removeItem(atPath: settingsFilePath)
    }

    private func writeSettingsFile() {
        let settings: [String: Any] = [
            "statusLine": [
                "type": "command",
                "command": "cat > '\(filePath)'"
            ]
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: settings, options: .prettyPrinted) else { return }
        try? data.write(to: URL(filePath: settingsFilePath))
    }

    @MainActor
    private func queryPR() {
        guard SettingsPersistence.isPRTrackingEnabled() else {
            currentData?.pr = nil
            return
        }
        guard let workingDirectory else { return }
        prQueryTask?.terminate()
        let task = Process()
        task.executableURL = URL(filePath: "/bin/zsh")
        task.arguments = ["-c", "cd '\(workingDirectory)' && branch=$(git branch --show-current 2>/dev/null) && [ -n \"$branch\" ] && gh pr view \"$branch\" --json number,title,state,url 2>/dev/null || true"]
        task.standardOutput = Pipe()
        task.standardError = Pipe()
        let output = task.standardOutput as! Pipe
        output.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let self else { return }
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let pr = try? JSONDecoder().decode(PullRequest.self, from: data) {
                    if self.currentData == nil {
                        self.currentData = StatusLineData(
                            model: nil, cost: nil, contextWindow: nil, rateLimits: nil,
                            worktree: nil, workspace: nil, effort: nil, thinking: nil,
                            agent: nil, outputStyle: nil, vim: nil,
                            sessionName: nil, version: nil, exceeds200kTokens: nil,
                            pr: pr
                        )
                    } else {
                        self.currentData?.pr = pr
                    }
                }
            }
        }
        prQueryTask = task
        do {
            try task.run()
        } catch {
            return
        }
    }
}
