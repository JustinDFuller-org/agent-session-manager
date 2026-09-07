import Foundation

enum GitDiffStats {
    static func compute(in workingDirectory: String) async -> (added: Int, removed: Int)? {
        await withCheckedContinuation { continuation in
            let task = Process()
            let outPipe = Pipe()
            task.executableURL = URL(filePath: "/bin/zsh")
            task.arguments = ["-c", "git diff --shortstat HEAD 2>/dev/null"]
            task.currentDirectoryURL = URL(filePath: workingDirectory)
            task.standardOutput = outPipe
            task.standardError = FileHandle.nullDevice
            task.terminationHandler = { process in
                let data = outPipe.fileHandleForReading.readDataToEndOfFile()
                guard process.terminationStatus == 0 else {
                    continuation.resume(returning: nil)
                    return
                }
                let output = String(data: data, encoding: .utf8) ?? ""
                continuation.resume(returning: GitDiffStats.parse(output))
            }
            do {
                try task.run()
            } catch {
                continuation.resume(returning: nil)
            }
        }
    }

    static func parse(_ output: String) -> (added: Int, removed: Int) {
        var added = 0
        var removed = 0
        for component in output.components(separatedBy: ",") {
            let trimmed = component.trimmingCharacters(in: .whitespaces)
            let parts = trimmed.components(separatedBy: " ")
            guard let count = parts.first.flatMap(Int.init) else { continue }
            if trimmed.contains("insertion") {
                added = count
            } else if trimmed.contains("deletion") {
                removed = count
            }
        }
        return (added, removed)
    }
}
