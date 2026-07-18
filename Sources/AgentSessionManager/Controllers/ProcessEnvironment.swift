import Foundation
import SwiftTerm

/// Sanitizes the environment inherited by a spawned terminal pane.
///
/// Pane harnesses are launched with `zsh -i -c <harness>`. When Agent Session Manager is
/// launched from a terminal (`make run`), the app inherits the parent shell's full environment
/// (PATH includes Homebrew, nvm, go; TERM is set to `xterm-256color`). When launched from the
/// DMG via Finder, LaunchServices provides a minimal environment: PATH is only
/// `/usr/bin:/bin:/usr/sbin:/sbin` and TERM/COLORTERM/LANG are unset.
///
/// This helper merges the inherited environment with a baseline that matches what SwiftTerm
/// advertises and what macOS provides to login shells:
/// - `TERM=xterm-256color` and `COLORTERM=truecolor` if unset (SwiftTerm's default terminal
///   capabilities, plus true-color support; see `Terminal.getEnvironmentVariables`).
/// - `LANG=en_US.UTF-8` if unset.
/// - A complete PATH built from `/etc/paths` and `/etc/paths.d/*` (the same files
///   `/usr/libexec/path_helper` reads) so tools like `go`, `brew`, and `nvm` are findable even
///   when the GUI gives us a minimal PATH.
///
/// User-set values are always preserved. The function is intentionally non-mutating: it takes
/// the `KEY=VALUE` array form used by `TerminalController.pendingEnvironment` and returns a new
/// `KEY=VALUE` array.
enum ProcessEnvironment {
    /// Returns the environment array with the baseline merged in.
    nonisolated static func sanitize(_ env: [String]) -> [String] {
        var values: [String: String] = [:]
        for entry in env {
            guard let separator = entry.firstIndex(of: "=") else { continue }
            let key = String(entry[..<separator])
            let value = String(entry[entry.index(after: separator)...])
            values[key] = value
        }

        // Fill in SwiftTerm's recommended baseline entries only when absent.
        for baseline in swiftTermBaseline() {
            guard let separator = baseline.firstIndex(of: "=") else { continue }
            let key = String(baseline[..<separator])
            let value = String(baseline[baseline.index(after: separator)...])
            if values[key] == nil {
                values[key] = value
            }
        }

        // Merge PATH with the system default entries so `go`, `brew`, etc. are findable.
        let currentPath = values["PATH"] ?? ""
        values["PATH"] = mergedPATH(currentPath: currentPath, defaultEntries: defaultPATHEntries())

        return values.map { "\($0.key)=\($0.value)" }
    }

    /// The SwiftTerm-recommended baseline for terminal child processes.
    nonisolated static func swiftTermBaseline() -> [String] {
        Terminal.getEnvironmentVariables(termName: "xterm-256color", trueColor: true)
    }

    /// System default PATH entries, read from `/etc/paths` and `/etc/paths.d/*` in the same
    /// order macOS uses for login shells. Falls back to a hardcoded list if the system files
    /// cannot be read.
    nonisolated static func defaultPATHEntries(
        etcDirectory: String = "/etc",
        fileManager: FileManager = .default
    ) -> [String] {
        let pathsFile = (etcDirectory as NSString).appendingPathComponent("paths")
        let pathsDir = (etcDirectory as NSString).appendingPathComponent("paths.d")

        var entries: [String] = []

        if let content = try? String(contentsOfFile: pathsFile, encoding: .utf8) {
            entries.append(contentsOf: parsePATHLines(content))
        }

        if let files = try? fileManager.contentsOfDirectory(atPath: pathsDir) {
            for file in files.sorted() {
                let fullPath = (pathsDir as NSString).appendingPathComponent(file)
                if let content = try? String(contentsOfFile: fullPath, encoding: .utf8) {
                    entries.append(contentsOf: parsePATHLines(content))
                }
            }
        }

        return entries.isEmpty ? fallbackPATHEntries : entries
    }

    /// Splits a `/etc/paths`-style file into non-empty, trimmed entries.
    nonisolated static func parsePATHLines(_ content: String) -> [String] {
        content
            .split(whereSeparator: { $0.isNewline || $0 == " " || $0 == ":" })
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    /// Merges the inherited PATH with the default entries, keeping defaults first and removing
    /// duplicates while preserving the user's original order. Empty entries are stripped.
    nonisolated static func mergedPATH(currentPath: String, defaultEntries: [String]) -> String {
        let currentParts = currentPath.split(separator: ":", omittingEmptySubsequences: true)
            .map { String($0) }

        var seen = Set<String>()
        var result: [String] = []

        for entry in defaultEntries where !seen.contains(entry) {
            result.append(entry)
            seen.insert(entry)
        }

        for entry in currentParts where !seen.contains(entry) {
            result.append(entry)
            seen.insert(entry)
        }

        return result.joined(separator: ":")
    }

    /// Hardcoded fallback used when the system PATH files cannot be read.
    static let fallbackPATHEntries: [String] = [
        "/usr/local/bin",
        "/opt/homebrew/bin",
        "/opt/homebrew/sbin",
        "/usr/local/go/bin",
        "/usr/bin",
        "/bin",
        "/usr/sbin",
        "/sbin",
    ]
}
