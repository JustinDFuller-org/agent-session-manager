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
    let httpStatus: Int?
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
                stdout: Data(), stderrPrefix: "", exitCode: nil, httpStatus: nil, failure: .missingExecutable)
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
            return GitHubCLIResult(stdout: Data(), stderrPrefix: "", exitCode: nil, httpStatus: nil, failure: .launch)
        }

        async let output = Task.detached { stdout.fileHandleForReading.readDataToEndOfFile() }.value
        async let errors = Task.detached { stderr.fileHandleForReading.readDataToEndOfFile() }.value
        let finished = await withTaskCancellationHandler(
            operation: { await waitForTermination(process, timeout: timeout) },
            onCancel: { process.terminate() })
        if !finished { process.terminate() }
        let (outData, errData) = await (output, errors)
        if Task.isCancelled {
            return GitHubCLIResult(
                stdout: outData, stderrPrefix: "", exitCode: nil, httpStatus: nil, failure: .cancelled)
        }
        let stderrText = String(data: errData.prefix(Self.stderrPrefixLimit), encoding: .utf8) ?? ""
        if !finished {
            return GitHubCLIResult(
                stdout: outData, stderrPrefix: stderrText, exitCode: nil, httpStatus: nil, failure: .timeout)
        }
        let status = process.terminationStatus
        let httpStatus = Self.httpStatus(in: stderrText)
        let failure = Self.classify(exitCode: status, stderr: stderrText)
        return GitHubCLIResult(
            stdout: outData, stderrPrefix: stderrText, exitCode: status, httpStatus: httpStatus, failure: failure)
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
        fileManager.isExecutableFile(atPath: path) && !fileManager.directoryExists(atPath: path)
    }

    private func waitForTermination(_ process: Process, timeout: TimeInterval) async -> Bool {
        guard process.isRunning else { return true }
        return await withTaskGroup(of: Bool.self, returning: Bool.self) { group in
            group.addTask {
                await withCheckedContinuation { continuation in
                    process.terminationHandler = { _ in continuation.resume(returning: ()) }
                }
                return true
            }
            group.addTask {
                try? await Task.sleep(for: .seconds(timeout))
                return false
            }
            let result = await group.next() ?? false
            group.cancelAll()
            return result
        }
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

    static func httpStatus(in text: String) -> Int? {
        let expression = try? NSRegularExpression(pattern: "HTTP/[0-9.]+ ([0-9]{3})")
        guard let match = expression?.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
            let range = Range(match.range(at: 1), in: text)
        else { return nil }
        return Int(text[range])
    }
}

extension FileManager {
    fileprivate func directoryExists(atPath path: String) -> Bool {
        var isDirectory: ObjCBool = false
        return fileExists(atPath: path, isDirectory: &isDirectory) && isDirectory.boolValue
    }
}
