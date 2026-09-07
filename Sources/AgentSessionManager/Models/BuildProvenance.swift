import Foundation

struct BuildProvenance: Equatable {
    let commit: String
    let branch: String
    let commitDate: Date?

    var isMainSourceBuild: Bool { branch == "main" }

    static func current(bundle: Bundle = .main) -> BuildProvenance? {
        from(infoDictionary: bundle.infoDictionary ?? [:])
    }

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
