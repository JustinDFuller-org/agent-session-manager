import Foundation
import Observation

@Observable
@MainActor
final class InvariantRepository {
    var violations: [InvariantViolation] = []
    var writerError: String?

    private let fileURL: URL
    private var source: DispatchSourceFileSystemObject?

    init(directory: URL) {
        fileURL = directory.appending(path: "invariants.jsonl")
    }

    func start() {
        refresh()
        startWatcher()
    }

    func refresh() {
        writerError = InvariantReporter.shared.latestWriterError
        guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else {
            violations = []
            return
        }
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

    private func startWatcher() {
        source?.cancel()
        source = nil
        let fd = open(fileURL.path, O_EVTONLY)
        guard fd >= 0 else { return }
        let newSource = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .extend, .delete, .rename, .revoke],
            queue: .global(qos: .utility)
        )
        newSource.setEventHandler { [weak self, weak newSource] in
            let inodeLost = newSource?.data.isDisjoint(with: [.delete, .rename, .revoke]) == false
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.refresh()
                if inodeLost { self.startWatcher() }
            }
        }
        newSource.setCancelHandler { close(fd) }
        newSource.resume()
        source = newSource
    }
}
