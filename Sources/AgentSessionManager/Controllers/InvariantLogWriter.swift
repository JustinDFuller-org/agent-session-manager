import Foundation

final class InvariantLogWriter: @unchecked Sendable {
    static let truncationMarker = "--- [truncated older invariant entries] ---"

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

    func append(_ violation: InvariantViolation) throws {
        try queue.sync {
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
                marker: Self.truncationMarker,
                preserveMetadata: true
            )
        }
    }
}
