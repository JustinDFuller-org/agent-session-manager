import Foundation

/// Everything a custom field's command may need so it never has to recompute what the app
/// already knows (git branch, worktree, lines changed, model, cost, PR, profile, pane/tab identity).
struct CustomFieldExecutionContext {
    var currentData: StatusLineData?
    var paneID: UUID
    var paneName: String
    var tabID: UUID
    var tabName: String
    var harness: Harness
    var workingDirectory: String?
    var profileName: String?
}

enum CustomFieldExecutionFailure: String {
    case nonzeroExit = "nonzero_exit"
    case timeout
    case spawnError = "spawn_error"
    case emptyOutput = "empty_output"
    case stdinWrite = "stdin_write"
}

enum CustomFieldOutputKind: String {
    case text
    case structured
}

struct CustomFieldExecutionError: Equatable {
    let reason: CustomFieldExecutionFailure
    let exitCode: Int32?
    let inputFailure: ChildProcessInputWriteFailure?
}

enum CustomFieldExecutionResult {
    case success(CustomFieldRenderValue, outputKind: CustomFieldOutputKind)
    case failure(CustomFieldExecutionError)
}

/// Runs a `CustomStatusLineField`'s command: builds the stdin JSON context and env vars, executes
/// with a per-field timeout, strips ANSI escapes, and parses the result as structured JSON or plain text.
enum CustomFieldRunner {
    static let outputCharacterLimit = 200
    private static let environmentPrefix = "AGENT_SESSION_MANAGER"

    static func run(
        field: CustomStatusLineField, context: CustomFieldExecutionContext
    ) async -> CustomFieldExecutionResult {
        await execute(
            command: field.command,
            workingDirectory: context.workingDirectory,
            timeoutSeconds: field.timeoutSeconds,
            stdinPayload: buildContextPayload(context: context),
            environment: buildEnvironment(context: context)
        )
    }

    /// Claude hook-JSON-shaped stdin payload, plus everything the app additionally knows
    /// (pane/tab identity, harness, working directory, profile) that `StatusLineData` doesn't carry.
    static func buildContextPayload(context: CustomFieldExecutionContext) -> Data {
        var dict: [String: Any] = [:]
        if let currentData = context.currentData,
            let encoded = try? JSONEncoder().encode(currentData),
            let obj = try? JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        {
            dict = obj
        }
        // Defense in depth: a field's own/sibling resolved values must never reach a command,
        // even if a future change starts encoding customFields on StatusLineData.
        dict["custom_fields"] = nil
        dict["pane"] = ["id": context.paneID.uuidString, "name": context.paneName]
        dict["tab"] = ["id": context.tabID.uuidString, "name": context.tabName]
        dict["harness"] = context.harness.rawValue
        if let workingDirectory = context.workingDirectory {
            dict["working_directory"] = workingDirectory
        }
        if let profileName = context.profileName {
            dict["profile_name"] = profileName
        }
        return (try? JSONSerialization.data(withJSONObject: dict)) ?? Data()
    }

    /// Curated flat `AGENT_SESSION_MANAGER_*` env vars for one-liners that don't want to shell out to `jq`.
    /// Not exhaustive — the stdin JSON is the "everything" channel.
    static func buildEnvironment(context: CustomFieldExecutionContext) -> [String: String] {
        var env: [String: String] = [
            "\(environmentPrefix)_PANE_ID": context.paneID.uuidString,
            "\(environmentPrefix)_PANE_NAME": context.paneName,
            "\(environmentPrefix)_TAB_ID": context.tabID.uuidString,
            "\(environmentPrefix)_TAB_NAME": context.tabName,
            "\(environmentPrefix)_HARNESS": context.harness.rawValue,
        ]
        if let workingDirectory = context.workingDirectory {
            env["\(environmentPrefix)_WORKING_DIRECTORY"] = workingDirectory
        }
        if let profileName = context.profileName {
            env["\(environmentPrefix)_PROFILE_NAME"] = profileName
        }
        let data = context.currentData
        if let model = data?.model?.displayName ?? data?.model?.id {
            env["\(environmentPrefix)_MODEL"] = model
        }
        if let name = data?.worktree?.name {
            env["\(environmentPrefix)_WORKTREE_NAME"] = name
        }
        if let branch = data?.worktree?.branch {
            env["\(environmentPrefix)_WORKTREE_BRANCH"] = branch
        }
        if let cost = data?.cost?.totalCostUsd {
            env["\(environmentPrefix)_COST_USD"] = String(cost)
        }
        if let added = data?.cost?.totalLinesAdded {
            env["\(environmentPrefix)_LINES_ADDED"] = String(added)
        }
        if let removed = data?.cost?.totalLinesRemoved {
            env["\(environmentPrefix)_LINES_REMOVED"] = String(removed)
        }
        if let duration = data?.cost?.totalDurationMs {
            env["\(environmentPrefix)_DURATION_MS"] = String(duration)
        }
        if let repo = data?.repo {
            env["\(environmentPrefix)_REPO"] = "\(repo.owner)/\(repo.name)"
        }
        return env
    }

    /// Strips ANSI CSI escape sequences (color codes, cursor movement) — native `Text` can't render
    /// them, and scripts copied from terminal-statusline examples commonly emit color codes.
    static func stripANSI(_ input: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: "\u{1B}\\[[0-9;]*[A-Za-z]") else { return input }
        let range = NSRange(input.startIndex..., in: input)
        return regex.stringByReplacingMatches(in: input, range: range, withTemplate: "")
    }

    /// Plain text is the floor of the render contract: try structured JSON first, fall back to the
    /// first line of trimmed output, capped at `outputCharacterLimit`.
    static func parse(_ trimmedOutput: String) -> (CustomFieldRenderValue, outputKind: CustomFieldOutputKind) {
        if let data = trimmedOutput.data(using: .utf8),
            let decoded = try? JSONDecoder().decode(CustomFieldRenderValue.self, from: data),
            !decoded.isEmpty
        {
            return (decoded, .structured)
        }
        let firstLine = trimmedOutput.components(separatedBy: .newlines).first ?? trimmedOutput
        let capped = String(firstLine.prefix(outputCharacterLimit))
        return (CustomFieldRenderValue(text: capped, percent: nil, tint: nil, icon: nil), .text)
    }

    /// Mutable value shared between `Process` callbacks that fire on different queues; access is
    /// serialized by `resumeLock` in `execute`, so this is safe despite the `@unchecked Sendable`.
    private final class Box<Value>: @unchecked Sendable {
        var value: Value
        init(_ value: Value) { self.value = value }
    }

    private static func execute(
        command: String,
        workingDirectory: String?,
        timeoutSeconds: Int,
        stdinPayload: Data,
        environment: [String: String]
    ) async -> CustomFieldExecutionResult {
        await withCheckedContinuation { continuation in
            let process = Process()
            let outPipe = Pipe()
            let inPipe = Pipe()
            process.executableURL = URL(filePath: "/bin/zsh")
            process.arguments = ["-lc", command]
            if let workingDirectory {
                process.currentDirectoryURL = URL(filePath: workingDirectory)
            }
            var mergedEnvironment = ProcessInfo.processInfo.environment
            for (key, value) in environment { mergedEnvironment[key] = value }
            process.environment = mergedEnvironment
            process.standardOutput = outPipe
            process.standardInput = inPipe
            process.standardError = FileHandle.nullDevice

            let resumeLock = NSLock()
            let hasResumed = Box(false)
            @Sendable func resumeOnce(_ result: CustomFieldExecutionResult) {
                resumeLock.lock()
                defer { resumeLock.unlock() }
                guard !hasResumed.value else { return }
                hasResumed.value = true
                continuation.resume(returning: result)
            }

            process.terminationHandler = { finishedProcess in
                let data = outPipe.fileHandleForReading.readDataToEndOfFile()
                guard finishedProcess.terminationStatus == 0 else {
                    resumeOnce(
                        .failure(
                            CustomFieldExecutionError(
                                reason: .nonzeroExit,
                                exitCode: finishedProcess.terminationStatus,
                                inputFailure: nil)))
                    return
                }
                let stripped = stripANSI(String(data: data, encoding: .utf8) ?? "")
                let trimmed = stripped.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else {
                    resumeOnce(
                        .failure(
                            CustomFieldExecutionError(
                                reason: .emptyOutput,
                                exitCode: finishedProcess.terminationStatus,
                                inputFailure: nil)))
                    return
                }
                let (value, outputKind) = parse(trimmed)
                resumeOnce(.success(value, outputKind: outputKind))
            }

            do {
                try process.run()
            } catch {
                resumeOnce(
                    .failure(
                        CustomFieldExecutionError(
                            reason: .spawnError,
                            exitCode: nil,
                            inputFailure: nil)))
                return
            }

            let timeout = Double(max(1, timeoutSeconds))
            let deadline = ProcessInfo.processInfo.systemUptime + timeout
            if let inputFailure = ChildProcessInputWriter.write(
                stdinPayload,
                to: inPipe.fileHandleForWriting,
                timeout: timeout)
            {
                if process.isRunning { process.terminate() }
                resumeOnce(
                    .failure(
                        CustomFieldExecutionError(
                            reason: inputFailure.errorCode == ETIMEDOUT ? .timeout : .stdinWrite,
                            exitCode: nil,
                            inputFailure: inputFailure)))
                return
            }

            let remainingTimeout = deadline - ProcessInfo.processInfo.systemUptime
            guard remainingTimeout > 0 else {
                if process.isRunning { process.terminate() }
                resumeOnce(
                    .failure(
                        CustomFieldExecutionError(
                            reason: .timeout,
                            exitCode: nil,
                            inputFailure: nil)))
                return
            }
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + remainingTimeout) {
                guard process.isRunning else { return }
                process.terminate()
                resumeOnce(
                    .failure(
                        CustomFieldExecutionError(
                            reason: .timeout,
                            exitCode: nil,
                            inputFailure: nil)))
            }
        }
    }
}
