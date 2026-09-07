import Foundation

struct CustomFieldExecutionContext {
    var currentData: StatusLineData?
    var paneID: UUID
    var paneName: String
    var tabID: UUID
    var tabName: String
    var harness: Harness
    var workingDirectory: String?
    var profileName: String?
    var extraEnvironment: [String: String] = [:]
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

    static func buildContextPayload(context: CustomFieldExecutionContext) -> Data {
        var dict: [String: Any] = [:]
        if let currentData = context.currentData,
            let encoded = try? JSONEncoder().encode(currentData),
            let obj = try? JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        {
            dict = obj
        }
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

    static func buildEnvironment(context: CustomFieldExecutionContext) -> [String: String] {
        var env = context.extraEnvironment
        env["\(environmentPrefix)_PANE_ID"] = context.paneID.uuidString
        env["\(environmentPrefix)_PANE_NAME"] = context.paneName
        env["\(environmentPrefix)_TAB_ID"] = context.tabID.uuidString
        env["\(environmentPrefix)_TAB_NAME"] = context.tabName
        env["\(environmentPrefix)_HARNESS"] = context.harness.rawValue
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

    static func stripANSI(_ input: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: "\u{1B}\\[[0-9;]*[A-Za-z]") else { return input }
        let range = NSRange(input.startIndex..., in: input)
        return regex.stringByReplacingMatches(in: input, range: range, withTemplate: "")
    }

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
            process.arguments = ["-i", "-c", command]
            if let workingDirectory {
                process.currentDirectoryURL = URL(filePath: workingDirectory)
            }
            let hostEnvironment = ProcessInfo.processInfo.environment.filter {
                !$0.key.hasPrefix("__CF")
            }
            var environmentEntries = hostEnvironment.map { "\($0.key)=\($0.value)" }
            environmentEntries.append(contentsOf: environment.map { "\($0.key)=\($0.value)" })
            var mergedEnvironment: [String: String] = [:]
            for entry in ProcessEnvironment.sanitize(environmentEntries) {
                guard let separator = entry.firstIndex(of: "=") else { continue }
                let key = String(entry[..<separator])
                let value = String(entry[entry.index(after: separator)...])
                mergedEnvironment[key] = value
            }
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
