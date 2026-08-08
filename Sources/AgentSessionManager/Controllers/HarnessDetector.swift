import Foundation

struct OhMyPiVersion: Comparable, Equatable {
    let major: Int
    let minor: Int
    let patch: Int

    static func < (lhs: OhMyPiVersion, rhs: OhMyPiVersion) -> Bool {
        (lhs.major, lhs.minor, lhs.patch) < (rhs.major, rhs.minor, rhs.patch)
    }

    var displayString: String {
        "\(major).\(minor).\(patch)"
    }
}

enum OhMyPiCompatibilityResult: Equatable {
    case supported(OhMyPiVersion)
    case missing
    case unparseable
    case unsupported(OhMyPiVersion)
    case launchFailed

    var telemetryResult: String {
        switch self {
        case .supported: "supported"
        case .missing: "missing"
        case .unparseable: "unparseable"
        case .unsupported: "unsupported"
        case .launchFailed: "launch_failed"
        }
    }

    var errorDescription: String {
        switch self {
        case .supported:
            ""
        case .missing:
            "Oh My Pi was not found in the selected shell's PATH. Install Oh My Pi, then reopen this sheet."
        case .unparseable:
            "Oh My Pi returned an unrecognized version. Install a version from the supported range (>= 17.2.11, < 18.0.0)."
        case .unsupported(let version):
            "Oh My Pi \(version.displayString) is unsupported. Install a version from the supported range (>= 17.2.11, < 18.0.0)."
        case .launchFailed:
            "Oh My Pi could not report its version. Check the selected shell configuration and try again."
        }
    }
}

struct OhMyPiProbeResult: Sendable {
    let status: Int32
    let stdout: String
    let stderr: String
}

private let ohMyPiMinimumVersion = OhMyPiVersion(major: 17, minor: 2, patch: 11)
private let ohMyPiMaximumVersion = OhMyPiVersion(major: 18, minor: 0, patch: 0)

private func boundedString(_ data: Data, limit: Int = 4 * 1024) -> String {
    String(data: data.prefix(limit), encoding: .utf8) ?? ""
}

enum HarnessDetector {
    typealias ShellRunner = @Sendable (String, String) async -> Bool

    typealias OhMyPiProbeRunner = @Sendable (String, String) async -> OhMyPiProbeResult

    static func checkOhMyPiCompatibility(
        shell: String,
        runner: OhMyPiProbeRunner? = nil
    ) async -> OhMyPiCompatibilityResult {
        let run =
            runner ?? { shell, command in
                await withCheckedContinuation { continuation in
                    let process = Process()
                    let stdout = Pipe()
                    let stderr = Pipe()
                    process.executableURL = URL(filePath: shell)
                    process.arguments = ["-i", "-c", command]
                    process.standardOutput = stdout
                    process.standardError = stderr
                    process.terminationHandler = { process in
                        continuation.resume(
                            returning: .init(
                                status: process.terminationStatus,
                                stdout: boundedString(stdout.fileHandleForReading.readDataToEndOfFile()),
                                stderr: boundedString(stderr.fileHandleForReading.readDataToEndOfFile())
                            )
                        )
                    }
                    do {
                        try process.run()
                    } catch {
                        continuation.resume(returning: .init(status: -1, stdout: "", stderr: ""))
                    }
                }
            }
        let probe = await run(shell, "command -v omp >/dev/null 2>&1 || exit 127; omp --version")
        guard probe.status != 127 else { return .missing }
        guard probe.status == 0 else { return .launchFailed }

        let trimmed = probe.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        let versionText: String
        if trimmed.hasPrefix("omp v") {
            versionText = String(trimmed.dropFirst("omp v".count))
        } else if trimmed.hasPrefix("omp/") {
            // OMP 17.2.11 prints this form despite its documented `omp v…` form.
            versionText = String(trimmed.dropFirst("omp/".count))
        } else {
            return .unparseable
        }
        let components = versionText.split(separator: ".", omittingEmptySubsequences: false)
        guard components.count == 3,
            let major = Int(components[0]),
            let minor = Int(components[1]),
            let patch = Int(components[2]),
            major >= 0, minor >= 0, patch >= 0
        else {
            return .unparseable
        }
        let version = OhMyPiVersion(major: major, minor: minor, patch: patch)
        return version >= ohMyPiMinimumVersion && version < ohMyPiMaximumVersion
            ? .supported(version)
            : .unsupported(version)
    }

    static func isInstalled(harness: Harness, shell: String, runner: ShellRunner? = nil) async -> Bool {
        let cmd = harness.commandDescription
        if let run = runner {
            return await run(shell, cmd)
        }
        return await withCheckedContinuation { continuation in
            let process = Process()
            let outPipe = Pipe()
            process.executableURL = URL(filePath: shell)
            process.arguments = ["-i", "-c", "which \(cmd)"]
            process.standardOutput = outPipe
            process.standardError = FileHandle.nullDevice
            process.terminationHandler = { proc in
                let data = outPipe.fileHandleForReading.readDataToEndOfFile()
                let output = (String(data: data, encoding: .utf8) ?? "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                continuation.resume(returning: proc.terminationStatus == 0 && !output.isEmpty)
            }
            do {
                try process.run()
            } catch {
                continuation.resume(returning: false)
            }
        }
    }

    static func detectInstalled(
        shell: String,
        runner: ShellRunner? = nil
    ) async -> Set<Harness> {
        return await withTaskGroup(of: Harness?.self) { group in
            for tool in Harness.allCases {
                let cmd = tool.commandDescription
                group.addTask {
                    if let run = runner {
                        return await run(shell, cmd) ? tool : nil
                    }
                    return await withCheckedContinuation { continuation in
                        let process = Process()
                        let outPipe = Pipe()
                        process.executableURL = URL(filePath: shell)
                        process.arguments = ["-i", "-c", "which \(cmd)"]
                        process.standardOutput = outPipe
                        process.standardError = FileHandle.nullDevice
                        process.terminationHandler = { proc in
                            let data = outPipe.fileHandleForReading.readDataToEndOfFile()
                            let output = (String(data: data, encoding: .utf8) ?? "")
                                .trimmingCharacters(in: .whitespacesAndNewlines)
                            continuation.resume(returning: proc.terminationStatus == 0 && !output.isEmpty ? tool : nil)
                        }
                        do {
                            try process.run()
                        } catch {
                            continuation.resume(returning: nil)
                        }
                    }
                }
            }
            var found = Set<Harness>()
            for await result in group {
                if let tool = result { found.insert(tool) }
            }
            return found
        }
    }
}
