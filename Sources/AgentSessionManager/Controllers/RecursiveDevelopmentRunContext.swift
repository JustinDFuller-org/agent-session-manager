import Foundation

/// Dev-only, argument-derived storage isolation for an agent-owned validation run.
/// The argument deliberately accepts a UUID, never a filesystem path.
enum RecursiveDevelopmentRunContext {
    static let launchArgument = "--recursive-development-run-id"
    static let supportParentName = "agent-session-manager-recursive-runs"

    struct Run: Equatable, Sendable {
        let id: UUID

        var idString: String { id.uuidString.lowercased() }
        var titleSuffix: String { String(idString.prefix(8)) }
        var persistenceSubdirectory: String {
            "\(supportParentName)/\(idString)/agent-session-manager.dev"
        }

        func supportDirectory(applicationSupport: URL) -> URL {
            applicationSupport.appending(path: persistenceSubdirectory).standardizedFileURL
        }
    }

    enum LaunchError: Error, Equatable {
        case missingRunID
        case duplicateRunID
        case malformedRunID
        case unsupportedInProduction
    }

    static func parse(arguments: [String]) throws -> Run? {
        let indexes = arguments.indices.filter { arguments[$0] == launchArgument }
        guard !indexes.isEmpty else { return nil }
        guard indexes.count == 1 else { throw LaunchError.duplicateRunID }
        let index = indexes[0]
        guard arguments.indices.contains(index + 1) else { throw LaunchError.missingRunID }
        let value = arguments[index + 1]
        guard let id = UUID(uuidString: value), id.uuidString.lowercased() == value.lowercased() else {
            throw LaunchError.malformedRunID
        }
        return Run(id: id)
    }

    static func validatedRun(arguments: [String], isDevBuild: Bool) throws -> Run? {
        let run = try parse(arguments: arguments)
        if run != nil && !isDevBuild {
            throw LaunchError.unsupportedInProduction
        }
        return run
    }

    /// Called before AppState/AppSettings construction. A production binary exits before
    /// any production persistence path can be resolved when it receives this Dev-only flag.
    static func validateProcessLaunch() -> Run? {
        do {
            let run = try validatedRun(
                arguments: CommandLine.arguments,
                isDevBuild: {
                    #if DEV_BUILD
                    true
                    #else
                    false
                    #endif
                }())
            return run
        } catch {
            fatalError("Invalid recursive development launch: \(error)")
        }
    }
}
