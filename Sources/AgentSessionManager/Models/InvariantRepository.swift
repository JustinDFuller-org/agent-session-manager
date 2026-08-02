import Foundation
import Observation

@Observable
@MainActor
final class InvariantRepository {
    var violations: [InvariantViolation] = []
    var writerError: String?
    var watcherError: String?

    private let fileURL: URL
    private var watcher: FileSystemEventWatcher?

    init(directory: URL) {
        fileURL = directory.appending(path: "invariants.jsonl")
    }

    func start() {
        refresh()
        watcher?.cancel()
        watcher = FileSystemEventWatcher(
            url: fileURL,
            followsReplacement: true,
            onEvent: { [weak self] _ in
                self?.refresh()
            },
            onStateChange: { [weak self] state in
                guard let self else { return }
                switch state {
                case .started, .recovered:
                    watcherError = nil
                    refresh()
                case .waitingForFile(let openError):
                    violations = []
                    watcherError = "Waiting for invariant log (errno \(openError))."
                case .stopped:
                    break
                }
            }
        )
        watcher?.start()
    }

    func refresh() {
        writerError = InvariantReporter.shared.latestWriterError
        guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else { return }
        violations = Self.parse(content).sorted { $0.timestamp > $1.timestamp }
    }

    static func parse(_ content: String) -> [InvariantViolation] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return content.components(separatedBy: "\n").compactMap { line in
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("--- [truncated older invariant entries] ---") else {
                return nil
            }
            guard let data = trimmed.data(using: .utf8) else { return nil }
            return try? decoder.decode(InvariantViolation.self, from: data)
        }
    }
}
