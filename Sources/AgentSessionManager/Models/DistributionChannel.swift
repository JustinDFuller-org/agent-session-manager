import Foundation

enum DistributionChannel: String, Equatable, Sendable {
    case sourceMain
    case dmg
    case unknown

    static func current(bundle: Bundle = .main) -> DistributionChannel {
        from(infoDictionary: bundle.infoDictionary ?? [:])
    }

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
