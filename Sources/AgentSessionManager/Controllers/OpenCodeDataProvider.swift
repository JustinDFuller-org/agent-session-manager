import Foundation

final class OpenCodeDataProvider: StatusLineDataProvider {
    var onUpdate: ((StatusLineData) -> Void)?

    private let workingDirectory: String
    private let processStartTime: Date
    private var refreshTimer: Timer?
    private var cachedPort: Int?
    private var cachedVersion: String?

    init(workingDirectory: String, processStartTime: Date) {
        self.workingDirectory = workingDirectory
        self.processStartTime = processStartTime
    }

    func start() {
        Task { [weak self] in await self?.refreshNow() }
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            Task { [weak self] in await self?.refreshNow() }
        }
    }

    func stop() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    var currentDurationMs: Double {
        max(0, Date().timeIntervalSince(processStartTime)) * 1000
    }

    // MARK: - Port Discovery

    private func discoverPort() async -> Int? {
        if let port = await probePort(4096) {
            return port
        }
        let configURL = configFileURL()
        guard let data = try? Data(contentsOf: configURL),
              let port = Self.parsePort(from: data)
        else { return nil }
        return await probePort(port)
    }

    private func probePort(_ port: Int) async -> Int? {
        guard let url = URL(string: "http://localhost:\(port)/global/health") else { return nil }
        var request = URLRequest(url: url, timeoutInterval: 2.0)
        request.httpMethod = "GET"
        guard let (_, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200
        else { return nil }
        return port
    }

    private func configFileURL() -> URL {
        let base: URL
        if let xdg = ProcessInfo.processInfo.environment["XDG_CONFIG_HOME"],
           !xdg.isEmpty {
            base = URL(filePath: xdg)
        } else {
            base = FileManager.default.homeDirectoryForCurrentUser.appending(path: ".config")
        }
        return base.appending(path: "opencode/opencode.json")
    }

    // MARK: - API Fetching

    private func fetchVersion(baseURL: String) async -> String? {
        guard let url = URL(string: "\(baseURL)/global/health") else { return nil }
        var request = URLRequest(url: url, timeoutInterval: 2.0)
        request.httpMethod = "GET"
        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let decoded = try? JSONDecoder().decode(HealthResponse.self, from: data)
        else { return nil }
        return decoded.version
    }

    private func findLatestSession(baseURL: String) async -> OpenCodeSession? {
        guard let encodedDir = workingDirectory.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(baseURL)/session")
        else { return nil }
        var request = URLRequest(url: url, timeoutInterval: 2.0)
        request.httpMethod = "GET"
        request.setValue(encodedDir, forHTTPHeaderField: "x-opencode-directory")
        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let sessions = try? JSONDecoder().decode([OpenCodeSession].self, from: data)
        else { return nil }
        return sessions.max { ($0.time.updated ?? $0.time.created) < ($1.time.updated ?? $1.time.created) }
    }

    private func fetchMessages(baseURL: String, sessionID: String) async -> [OpenCodeMessage] {
        guard let encodedDir = workingDirectory.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(baseURL)/session/\(sessionID)/message")
        else { return [] }
        var request = URLRequest(url: url, timeoutInterval: 2.0)
        request.httpMethod = "GET"
        request.setValue(encodedDir, forHTTPHeaderField: "x-opencode-directory")
        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let messages = try? JSONDecoder().decode([OpenCodeMessage].self, from: data)
        else { return [] }
        return messages
    }

    private func fetchStatus(baseURL: String, sessionID: String) async -> String? {
        guard let encodedDir = workingDirectory.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(baseURL)/session/status")
        else { return nil }
        var request = URLRequest(url: url, timeoutInterval: 2.0)
        request.httpMethod = "GET"
        request.setValue(encodedDir, forHTTPHeaderField: "x-opencode-directory")
        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let dict = try? JSONDecoder().decode([String: SessionStatusEntry].self, from: data)
        else { return nil }
        return Self.mapStatus(dict, sessionID: sessionID)
    }

    // MARK: - Refresh

    private func refreshNow() async {
        let branch = await runShell("git branch --show-current 2>/dev/null")?.trimmingCharacters(in: .whitespacesAndNewlines)
        let wd = workingDirectory

        var modelInfo: StatusLineData.Model?
        var contextWindow: StatusLineData.ContextWindow?
        var costInfo: StatusLineData.Cost?
        var sessionStatus: StatusLineData.SessionStatus?
        var openCodeMode: String?

        if cachedPort == nil {
            cachedPort = await discoverPort()
        }

        if let port = cachedPort {
            let base = "http://localhost:\(port)"

            if cachedVersion == nil {
                cachedVersion = await fetchVersion(baseURL: base)
            }

            if let session = await findLatestSession(baseURL: base) {
                let messages = await fetchMessages(baseURL: base, sessionID: session.id)
                let statusType = await fetchStatus(baseURL: base, sessionID: session.id)
                let aggregated = Self.aggregateMessages(messages)

                openCodeMode = aggregated.mode

                if let m = session.model {
                    let parts = [m.providerID, m.modelID].compactMap { $0 }
                    let mid = parts.joined(separator: "/")
                    if !mid.isEmpty {
                        modelInfo = StatusLineData.Model(id: mid, displayName: mid)
                    }
                }
                if aggregated.inputTokens > 0 || aggregated.outputTokens > 0 {
                    contextWindow = StatusLineData.ContextWindow(
                        usedPercentage: nil,
                        remainingPercentage: nil,
                        totalInputTokens: aggregated.inputTokens,
                        totalOutputTokens: aggregated.outputTokens
                    )
                }
                if aggregated.cost > 0 {
                    costInfo = StatusLineData.Cost(
                        totalCostUsd: aggregated.cost,
                        totalDurationMs: currentDurationMs,
                        totalLinesAdded: nil,
                        totalLinesRemoved: nil
                    )
                }
                sessionStatus = statusType.map { StatusLineData.SessionStatus(state: $0) }
            }
        }

        let data = StatusLineData(
            model: modelInfo,
            cost: costInfo ?? StatusLineData.Cost(
                totalCostUsd: nil,
                totalDurationMs: currentDurationMs,
                totalLinesAdded: nil,
                totalLinesRemoved: nil
            ),
            contextWindow: contextWindow,
            rateLimits: nil,
            worktree: StatusLineData.Worktree(
                name: URL(filePath: wd).lastPathComponent,
                branch: branch
            ),
            workspace: StatusLineData.Workspace(gitWorktree: wd),
            effort: nil,
            thinking: nil,
            agent: nil,
            outputStyle: nil,
            vim: nil,
            sessionName: nil,
            version: cachedVersion,
            exceeds200kTokens: nil,
            sessionStatus: sessionStatus,
            openCodeMode: openCodeMode,
            pr: nil
        )

        await MainActor.run { [weak self] in
            self?.onUpdate?(data)
        }
    }

    private func runShell(_ command: String) async -> String? {
        await withCheckedContinuation { continuation in
            let task = Process()
            let outPipe = Pipe()
            task.executableURL = URL(filePath: "/bin/zsh")
            task.arguments = ["-c", command]
            task.currentDirectoryURL = URL(filePath: workingDirectory)
            task.standardOutput = outPipe
            task.standardError = FileHandle.nullDevice
            task.terminationHandler = { process in
                let data = outPipe.fileHandleForReading.readDataToEndOfFile()
                if process.terminationStatus == 0, !data.isEmpty {
                    continuation.resume(returning: String(data: data, encoding: .utf8))
                } else {
                    continuation.resume(returning: nil)
                }
            }
            do {
                try task.run()
            } catch {
                continuation.resume(returning: nil)
            }
        }
    }

    // MARK: - Internal Parsing Helpers (internal for testing)

    static func parsePort(from configData: Data) -> Int? {
        guard let json = try? JSONSerialization.jsonObject(with: configData) as? [String: Any],
              let server = json["server"] as? [String: Any],
              let port = server["port"] as? Int
        else { return nil }
        return port
    }

    static func aggregateMessages(_ messages: [OpenCodeMessage]) -> (inputTokens: Int, outputTokens: Int, cost: Double, mode: String?) {
        var totalInput = 0
        var totalOutput = 0
        var totalCost = 0.0
        var lastMode: String?
        for msg in messages {
            totalInput += msg.tokens?.input ?? 0
            totalOutput += msg.tokens?.output ?? 0
            totalCost += msg.cost ?? 0
            if let mode = msg.mode { lastMode = mode }
        }
        return (totalInput, totalOutput, totalCost, lastMode)
    }

    static func mapStatus(_ dict: [String: SessionStatusEntry], sessionID: String) -> String? {
        dict[sessionID]?.type
    }
}

// MARK: - Private Decodable Types

private struct HealthResponse: Decodable {
    let version: String?
}

struct OpenCodeSession: Decodable {
    let id: String
    let model: SessionModel?
    let time: SessionTime

    struct SessionModel: Decodable {
        let providerID: String?
        let modelID: String?
        enum CodingKeys: String, CodingKey {
            case providerID = "providerID"
            case modelID = "modelID"
        }
    }

    struct SessionTime: Decodable {
        let created: Double
        let updated: Double?
    }
}

struct OpenCodeMessage: Decodable {
    let role: String?
    let mode: String?
    let tokens: MessageTokens?
    let cost: Double?

    struct MessageTokens: Decodable {
        let input: Int?
        let output: Int?
    }
}

struct SessionStatusEntry: Decodable {
    let type: String
}
