import Foundation

/// Git provenance embedded into `Info.plist` by `make app`/`make app-dev` (see Makefile).
/// Builds made any other way (Xcode, `swift build`, a future DMG/Homebrew install) have no
/// `ASMSource*` keys, so `current(bundle:)` returns `nil` and the update-reminder feature
/// that reads this stays dormant for them.
struct BuildProvenance: Equatable {
    let commit: String
    let branch: String
    let commitDate: Date?

    var isMainSourceBuild: Bool { branch == "main" }

    static func current(bundle: Bundle = .main) -> BuildProvenance? {
        from(infoDictionary: bundle.infoDictionary ?? [:])
    }

    /// Internal for testing: builds provenance from a raw info dictionary without needing a real `Bundle`.
    static func from(infoDictionary: [String: Any]) -> BuildProvenance? {
        guard
            let commit = infoDictionary["ASMSourceCommit"] as? String, !commit.isEmpty,
            let branch = infoDictionary["ASMSourceBranch"] as? String, !branch.isEmpty
        else { return nil }

        let dateString = infoDictionary["ASMSourceCommitDate"] as? String
        let commitDate = dateString.flatMap { ISO8601DateFormatter().date(from: $0) }
        return BuildProvenance(commit: commit, branch: branch, commitDate: commitDate)
    }
}
