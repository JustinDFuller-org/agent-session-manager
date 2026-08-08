import Foundation

private struct OhMyPiStatusSnapshot: Decodable {
    struct Usage: Decodable {
        let input: Int
        let output: Int
        let cacheRead: Int
        let cacheWrite: Int
        let cost: Double

        enum CodingKeys: String, CodingKey {
            case input, output, cost
            case cacheRead = "cache_read"
            case cacheWrite = "cache_write"
        }
    }

    struct Context: Decodable {
        let tokens: Int
        let contextWindow: Int
        let percent: Double

        enum CodingKeys: String, CodingKey {
            case tokens
            case contextWindow = "context_window"
            case percent
        }
    }

    struct Attention: Decodable {
        let sequence: Int
        let kind: String
        let reason: String
    }

    let schemaVersion: Int
    let eventSequence: Int
    let event: String
    let timestamp: String
    let sessionID: String?
    let sessionPersistent: Bool
    let sessionName: String?
    let modelID: String?
    let modelName: String?
    let modelProvider: String?
    let thinkingLevel: String?
    let usage: Usage
    let context: Context
    let isWorking: Bool
    let attention: Attention?

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case eventSequence = "event_sequence"
        case event, timestamp
        case sessionID = "session_id"
        case sessionPersistent = "session_persistent"
        case sessionName = "session_name"
        case modelID = "model_id"
        case modelName = "model_name"
        case modelProvider = "model_provider"
        case thinkingLevel = "thinking_level"
        case usage, context, attention
        case isWorking = "is_working"
    }
}

@MainActor
final class OhMyPiStatusProvider: StatusLineDataProvider {
    var onUpdate: ((StatusLineData) -> Void)?
    var onAttention: ((PaneAttentionEvent) -> Void)?
    var onAttentionResolved: ((PaneAttentionEvent.Source) -> Void)?
    var onWorkingChanged: ((Bool) -> Void)?
    var onSessionBound: ((String) -> Void)?
    var onSessionMismatch: (() -> Void)?

    private let context: StatusProviderContext
    private let agnostic: ToolAgnosticDataProvider
    private let statusURL: URL
    private var watcher: FileSystemEventWatcher?
    private var baseline: StatusLineData?
    private var snapshot: OhMyPiStatusSnapshot?
    private var lastSequence = -1
    private var lastAttentionSequence = -1
    private var pendingAttention: PaneAttentionEvent.Source?

    init(context: StatusProviderContext) {
        self.context = context
        statusURL = URL(filePath: context.ohMyPiStatusFilePath ?? "")
        agnostic = ToolAgnosticDataProvider(
            workingDirectory: context.workingDirectory,
            toolCommand: "omp",
            processStartTime: context.processStartTime)
    }

    func start() {
        agnostic.onUpdate = { [weak self] data in
            guard let self else { return }
            baseline = data
            publish()
        }
        agnostic.start()
        watcher = FileSystemEventWatcher(url: statusURL, followsReplacement: true) { [weak self] _ in
            self?.applyStatusFile()
        }
        watcher?.start()
        applyStatusFile()
    }

    func stop() {
        watcher?.cancel()
        watcher = nil
        agnostic.stop()
    }

    private func applyStatusFile() {
        guard let data = try? Data(contentsOf: statusURL) else { return }
        guard data.count <= 64 * 1024,
            let permissions = try? FileManager.default.attributesOfItem(atPath: statusURL.path)[.posixPermissions]
                as? NSNumber,
            permissions.intValue & 0o777 == 0o600,
            let decoded = try? JSONDecoder().decode(OhMyPiStatusSnapshot.self, from: data),
            decoded.schemaVersion == 2,
            decoded.eventSequence > lastSequence,
            decoded.eventSequence >= 0,
            decoded.event.count <= 64,
            decoded.timestamp.count <= 64,
            [
                decoded.sessionID, decoded.sessionName, decoded.modelID, decoded.modelName, decoded.modelProvider,
                decoded.thinkingLevel,
            ].allSatisfy({ $0?.count ?? 0 <= 256 }),
            decoded.usage.input >= 0,
            decoded.usage.output >= 0,
            decoded.usage.cacheRead >= 0,
            decoded.usage.cacheWrite >= 0,
            decoded.usage.cost.isFinite,
            decoded.usage.cost >= 0,
            decoded.context.tokens >= 0,
            decoded.context.contextWindow >= 0,
            decoded.context.percent.isFinite,
            decoded.context.percent >= 0,
            decoded.context.percent <= 100,
            decoded.attention.map({ $0.sequence >= 0 && $0.kind.count <= 32 && $0.reason.count <= 200 }) ?? true
        else {
            return
        }

        if let sessionID = decoded.sessionID, decoded.sessionPersistent, !sessionID.isEmpty,
            let expected = context.expectedOhMyPiSessionID, expected != sessionID
        {
            InvariantReporter.shared.violated(
                .ohMyPiSessionRebindable,
                context: [
                    "pane.id": context.paneID.uuidString,
                    "pane.name": context.paneName,
                    "tab.id": context.tabID.uuidString,
                    "tab.name": context.tabName,
                    "expected_id_prefix": String(expected.prefix(12)),
                    "observed_id_prefix": String(sessionID.prefix(12)),
                ])
            onSessionMismatch?()
            return
        }

        lastSequence = decoded.eventSequence
        let wasWorking = snapshot?.isWorking
        snapshot = decoded
        if let sessionID = decoded.sessionID, decoded.sessionPersistent, !sessionID.isEmpty {
            onSessionBound?(sessionID)
        }

        if decoded.event == "tool_approval_resolved", pendingAttention == .ohMyPiPermissionRequest {
            pendingAttention = nil
            onAttentionResolved?(.ohMyPiPermissionRequest)
        } else if decoded.event == "tool_result", pendingAttention == .ohMyPiInputRequest {
            pendingAttention = nil
            onAttentionResolved?(.ohMyPiInputRequest)
        }

        if wasWorking != decoded.isWorking {
            onWorkingChanged?(decoded.isWorking)
        }
        if let attention = decoded.attention, attention.sequence > lastAttentionSequence {
            lastAttentionSequence = attention.sequence
            switch attention.kind {
            case "finished":
                onAttention?(.ohMyPiStop)
            case "permission":
                pendingAttention = .ohMyPiPermissionRequest
                onAttention?(.init(source: .ohMyPiPermissionRequest, reason: attention.reason))
            case "input":
                pendingAttention = .ohMyPiInputRequest
                onAttention?(.init(source: .ohMyPiInputRequest, reason: attention.reason))
            default:
                break
            }
        }
        TracingService.shared.record(
            "statusline.omp.payload.applied",
            attributes: [
                "pane.id": context.paneID.uuidString,
                "pane.name": context.paneName,
                "tab.id": context.tabID.uuidString,
                "tab.name": context.tabName,
                "result": "applied",
            ])
        publish()
    }

    private func publish() {
        guard var data = baseline, let snapshot else { return }
        data.model = .init(id: snapshot.modelID, displayName: snapshot.modelName)
        data.cost = .init(
            totalCostUsd: snapshot.usage.cost,
            totalDurationMs: data.cost?.totalDurationMs,
            totalLinesAdded: data.cost?.totalLinesAdded,
            totalLinesRemoved: data.cost?.totalLinesRemoved)
        data.contextWindow = .init(
            usedPercentage: Int(snapshot.context.percent.rounded()),
            remainingPercentage: max(0, 100 - Int(snapshot.context.percent.rounded())),
            totalInputTokens: snapshot.usage.input,
            totalOutputTokens: snapshot.usage.output,
            contextWindowSize: snapshot.context.contextWindow,
            currentUsage: .init(
                inputTokens: 0,
                outputTokens: 0,
                cacheCreationInputTokens: snapshot.usage.cacheWrite,
                cacheReadInputTokens: snapshot.usage.cacheRead))
        data.effort = .init(level: snapshot.thinkingLevel)
        data.thinking = .init(enabled: snapshot.thinkingLevel != nil)
        data.sessionName = snapshot.sessionName
        onUpdate?(data)
    }
}
