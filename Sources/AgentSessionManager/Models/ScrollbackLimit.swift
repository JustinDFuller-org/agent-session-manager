import Foundation

enum ScrollbackLimit: Equatable, Sendable {
    case finite(Int)
    case unlimited

    static let defaultValue = ScrollbackLimit.finite(5_000)
    static let minimumLines = 100
    static let maximumFiniteLines = 50_000
    static let unlimitedLineCap = 50_000

    init(finiteLines: Int) {
        self = .finite(
            min(Self.maximumFiniteLines, max(Self.minimumLines, finiteLines))
        )
    }

    var resolvedLines: Int {
        switch self {
        case .finite(let lines):
            return min(Self.maximumFiniteLines, max(Self.minimumLines, lines))
        case .unlimited:
            return Self.unlimitedLineCap
        }
    }

    var modeName: String {
        switch self {
        case .finite:
            return "finite"
        case .unlimited:
            return "unlimited"
        }
    }
}

extension ScrollbackLimit: Codable {
    private enum CodingKeys: String, CodingKey {
        case mode
        case lines
    }

    private enum Mode: String, Codable {
        case finite
        case unlimited
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Mode.self, forKey: .mode) {
        case .finite:
            self.init(finiteLines: try container.decode(Int.self, forKey: .lines))
        case .unlimited:
            self = .unlimited
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .finite(let lines):
            try container.encode(Mode.finite, forKey: .mode)
            try container.encode(
                min(Self.maximumFiniteLines, max(Self.minimumLines, lines)),
                forKey: .lines
            )
        case .unlimited:
            try container.encode(Mode.unlimited, forKey: .mode)
        }
    }
}
