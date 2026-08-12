import Foundation

final class InvariantLogWriter: @unchecked Sendable {
    let fileURL: URL
    private let maxBytes: Int
    private let queue = DispatchQueue(
        label: "com.justinfuller.agent-session-manager.invariant-file",
        qos: .utility
    )

    init(directory: URL, maxBytes: Int) {
        fileURL = directory.appending(path: "invariants.jsonl")
        self.maxBytes = max(1, maxBytes)
    }

    /// Dispatches the write and returns immediately — callers (including `@MainActor` ones)
    /// never wait on file I/O. `completion` runs on `queue`, not the caller's original context.
    func append(_ violation: InvariantViolation, completion: @escaping (Result<Void, Error>) -> Void = { _ in }) {
        queue.async { [fileURL, maxBytes] in
            do {
                let fm = FileManager.default
                try fm.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                if !fm.fileExists(atPath: fileURL.path) {
                    let metadata = "{\"_type\":\"metadata\",\"schemaVersion\":1}\n"
                    try Data(metadata.utf8).write(to: fileURL)
                }
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                var data = try encoder.encode(violation)
                data.append(UInt8(ascii: "\n"))
                let handle = try FileHandle(forWritingTo: fileURL)
                defer { try? handle.close() }
                try handle.seekToEnd()
                try handle.write(contentsOf: data)
                try JSONLTrimmer.trimIfNeeded(
                    at: fileURL,
                    maxBytes: maxBytes,
                    preserveMetadata: true
                )
                completion(.success(()))
            } catch {
                completion(.failure(error))
            }
        }
    }
}
