import Foundation

enum RecursiveDevelopmentRuntimeState: String, Codable, Sendable {
    case starting
    case ready
    case stopped
}

struct RecursiveDevelopmentRuntimeManifest: Codable, Equatable, Sendable {
    let schemaVersion: Int
    let runID: String
    let state: RecursiveDevelopmentRuntimeState
    let pid: Int32
    let bundleURL: String
    let commit: String
    let windowTitle: String
    let timestamp: Date
}

enum RecursiveRunManifestWriter {
    static func write(
        state: RecursiveDevelopmentRuntimeState,
        run: RecursiveDevelopmentRunContext.Run,
        title: String
    ) {
        let support = run.supportDirectory(
            applicationSupport: FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0])
        let manifest = RecursiveDevelopmentRuntimeManifest(
            schemaVersion: 1,
            runID: run.idString,
            state: state,
            pid: ProcessInfo.processInfo.processIdentifier,
            bundleURL: Bundle.main.bundleURL.standardizedFileURL.path,
            commit: (Bundle.main.object(forInfoDictionaryKey: "ASMSourceCommit") as? String) ?? "unknown",
            windowTitle: title,
            timestamp: Date())
        do {
            try FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(manifest)
            try data.write(to: support.appending(path: "recursive-development-runtime.json"), options: .atomic)
        } catch {
            TracingService.shared.record(
                "recursive_development.run.manifest_failed", attributes: ["state": state.rawValue])
        }
    }
}
