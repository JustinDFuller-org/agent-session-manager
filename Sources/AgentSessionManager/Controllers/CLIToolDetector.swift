import Foundation

enum CLIToolDetector {
    typealias ShellRunner = @Sendable (String, String) async -> Bool

    static func detectInstalled(
        shell: String,
        runner: ShellRunner? = nil
    ) async -> Set<CLIType> {
        return await withTaskGroup(of: CLIType?.self) { group in
            for tool in CLIType.allCases {
                let cmd = tool.cliCommandDescription
                group.addTask {
                    if let run = runner {
                        return await run(shell, cmd) ? tool : nil
                    }
                    return await defaultProbe(shell: shell, command: cmd) ? tool : nil
                }
            }
            var found = Set<CLIType>()
            for await result in group {
                if let tool = result { found.insert(tool) }
            }
            return found
        }
    }

    private static func defaultProbe(shell: String, command: String) async -> Bool {
        await withCheckedContinuation { continuation in
            let process = Process()
            let outPipe = Pipe()
            process.executableURL = URL(filePath: shell)
            process.arguments = ["-i", "-c", "which \(command)"]
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
}
