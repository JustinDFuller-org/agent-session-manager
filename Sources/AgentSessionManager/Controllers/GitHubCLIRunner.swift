import Foundation

/// Direct, noninteractive runner for app-owned GitHub CLI requests.
protocol GitHubCLIRunning: Sendable {
    func run(arguments: [String], stdin: Data?, timeout: TimeInterval) async -> GitHubCLIResult
}

enum GitHubCLIFailure: String, Sendable, Equatable {
    case missingExecutable = "missing_executable"
    case launch
    case authentication
    case network
    case timeout
    case cancelled
    case api
    case parse
}

struct GitHubCLIResult: Sendable {
    let stdout: Data
    let stderrPrefix: String
    let exitCode: Int32?
    let failure: GitHubCLIFailure?

    var succeeded: Bool { failure == nil && exitCode == 0 }
}

final class GitHubCLIRunner: GitHubCLIRunning, @unchecked Sendable {
    static let shared = GitHubCLIRunner()
    static let stderrPrefixLimit = 1_024

    private let environment: [String: String]
    private let fileManager: FileManager

    init(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        fileManager: FileManager = .default
    ) {
        self.environment = Dictionary(
            uniqueKeysWithValues: ProcessEnvironment.sanitize(environment.map { "\($0.key)=\($0.value)" })
                .compactMap { entry in
                    guard let index = entry.firstIndex(of: "=") else { return nil }
                    return (String(entry[..<index]), String(entry[entry.index(after: index)...]))
                })
        self.fileManager = fileManager
    }

    func run(arguments: [String], stdin: Data? = nil, timeout: TimeInterval) async -> GitHubCLIResult {
        guard let executable = Self.resolveExecutable(environment: environment, fileManager: fileManager) else {
            return GitHubCLIResult(
                stdout: Data(), stderrPrefix: "", exitCode: nil, failure: .missingExecutable)
        }
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        var childEnvironment = environment
        childEnvironment["GH_PROMPT_DISABLED"] = "1"
        process.environment = childEnvironment
        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr
        if let stdin {
            let input = Pipe()
            process.standardInput = input
            DispatchQueue.global(qos: .userInitiated).async {
                input.fileHandleForWriting.write(stdin)
                try? input.fileHandleForWriting.close()
            }
        }
        do { try process.run() } catch {
            return GitHubCLIResult(stdout: Data(), stderrPrefix: "", exitCode: nil, failure: .launch)
        }

        let failure = await withTaskCancellationHandler(
            operation: {
                await withTaskGroup(of: GitHubCLIFailure?.self, returning: GitHubCLIFailure?.self) { group in
                    group.addTask {
                        await Task.detached { process.waitUntilExit() }.value
                        return nil
                    }
                    group.addTask {
                        do {
                            try await Task.sleep(for: .seconds(timeout))
                        } catch {
                            return nil
                        }
                        process.terminate()
                        return .timeout
                    }
                    let result = await group.next() ?? .timeout
                    group.cancelAll()
                    return result
                }
            },
            onCancel: { process.terminate() })
        let outData = stdout.fileHandleForReading.readDataToEndOfFile()
        let errData = stderr.fileHandleForReading.readDataToEndOfFile()
        if Task.isCancelled {
            return GitHubCLIResult(
                stdout: outData, stderrPrefix: "", exitCode: nil, failure: .cancelled)
        }
        let stderrText = String(data: errData.prefix(Self.stderrPrefixLimit), encoding: .utf8) ?? ""
        if failure == .timeout {
            return GitHubCLIResult(
                stdout: outData, stderrPrefix: stderrText, exitCode: nil, failure: .timeout)
        }
        let status = process.terminationStatus
        return GitHubCLIResult(
            stdout: outData, stderrPrefix: stderrText, exitCode: status,
            failure: Self.classify(exitCode: status, stderr: stderrText))
    }

    nonisolated static func resolveExecutable(
        environment: [String: String], fileManager: FileManager = .default
    ) -> URL? {
        if let configured = environment["GH_PATH"], isExecutable(configured, fileManager: fileManager) {
            return URL(filePath: configured)
        }
        for directory in (environment["PATH"] ?? "").split(separator: ":") {
            let candidate = (String(directory) as NSString).appendingPathComponent("gh")
            if isExecutable(candidate, fileManager: fileManager) { return URL(filePath: candidate) }
        }
        return nil
    }

    nonisolated private static func isExecutable(_ path: String, fileManager: FileManager) -> Bool {
        var isDirectory: ObjCBool = false
        return fileManager.isExecutableFile(atPath: path)
            && fileManager.fileExists(atPath: path, isDirectory: &isDirectory)
            && !isDirectory.boolValue
    }

    static func classify(exitCode: Int32, stderr: String) -> GitHubCLIFailure? {
        guard exitCode != 0 else { return nil }
        if exitCode == 4 { return .authentication }
        if exitCode == 2 { return .cancelled }
        let lower = stderr.lowercased()
        if [
            "no such host", "network is unreachable", "connection refused", "connection reset", "tls", "x509",
            "timeout",
        ].contains(where: lower.contains) {
            return .network
        }
        return .api
    }
}
