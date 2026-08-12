import Foundation

enum HarnessDetector {
    typealias ShellRunner = @Sendable (String, String) async -> Bool

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
                let data = ChildProcessOutputReader.readToEndOfFile(
                    outPipe.fileHandleForReading, site: "HarnessDetector.isInstalled")
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
                            let data = ChildProcessOutputReader.readToEndOfFile(
                                outPipe.fileHandleForReading, site: "HarnessDetector.detectInstalled")
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
