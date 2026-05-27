import Foundation

enum ShellResolver {
    static func detectedLoginShell() -> String {
        let env = ProcessInfo.processInfo.environment["SHELL"] ?? ""
        return env.isEmpty ? "/bin/zsh" : env
    }

    @MainActor
    static func resolved(_ settings: AppSettings) -> String {
        let preferred = settings.preferredShell.trimmingCharacters(in: .whitespacesAndNewlines)
        return preferred.isEmpty ? detectedLoginShell() : preferred
    }

    static var commonShells: [String] {
        ["/bin/zsh", "/bin/bash", "/bin/sh", "/bin/tcsh", "/opt/homebrew/bin/fish", "/usr/local/bin/fish"]
            .filter { FileManager.default.fileExists(atPath: $0) }
    }
}
