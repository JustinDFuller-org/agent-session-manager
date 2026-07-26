import Foundation

/// Identifies how this binary was produced, so update-detection can choose the right source.
/// - `sourceMain`: built from `main` via `make app`/`make app-dev` (the dev/dogfood path).
/// - `dmg`: a released DMG produced by `scripts/dist.sh`.
/// - `unknown`: anything else (Xcode builds, feature branches, `swift build`, etc.).
enum DistributionChannel: String, Equatable, Sendable {
    case sourceMain
    case dmg
    case unknown

    static func current(bundle: Bundle = .main) -> DistributionChannel {
        from(infoDictionary: bundle.infoDictionary ?? [:])
    }

    /// Internal for testing: resolves the channel from a raw info dictionary.
    static func from(infoDictionary: [String: Any]) -> DistributionChannel {
        if let raw = infoDictionary["ASMDistributionChannel"] as? String {
            switch raw {
            case "dmg": return .dmg
            case "sourceMain": return .sourceMain
            default: return .unknown
            }
        }
        if let provenance = BuildProvenance.from(infoDictionary: infoDictionary), provenance.isMainSourceBuild {
            return .sourceMain
        }
        return .unknown
    }
}
