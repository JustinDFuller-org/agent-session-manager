import Foundation

/// Rotates a JSONL file once it crosses `maxBytes`, instead of reading it whole and rewriting a
/// trimmed copy. A rename is a constant-cost directory operation regardless of file size, so this
/// avoids both the ~2x-file-size transient allocation of read-and-rewrite and the window where an
/// abrupt process death leaves an `.atomic`-write `.sb-*` temporary instead of a real file.
///
/// At most one rotated generation is kept per file (`<name>.1.jsonl`); a second rotation replaces
/// it. `TraceCleanupService` reclaims rotated generations past retention the same way it reclaims
/// the active file.
enum JSONLTrimmer {
    static func trimIfNeeded(at url: URL, maxBytes: Int, preserveMetadata: Bool = false) throws {
        let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
        guard let size = (attrs[.size] as? NSNumber)?.intValue, size > maxBytes else { return }

        let metadataLine = preserveMetadata ? try? firstMetadataLine(at: url) : nil

        let rotatedURL = rotatedURL(for: url)
        try? FileManager.default.removeItem(at: rotatedURL)
        try FileManager.default.moveItem(at: url, to: rotatedURL)

        if let metadataLine {
            try Data((metadataLine + "\n").utf8).write(to: url, options: .atomic)
        }
    }

    static func rotatedURL(for url: URL) -> URL {
        let baseName = url.deletingPathExtension().lastPathComponent
        return url.deletingLastPathComponent().appending(path: "\(baseName).1.jsonl")
    }

    /// Reads only as many leading chunks as needed to find the first line, so extracting the
    /// metadata header never approaches the file's full (possibly `maxBytes`-sized) length.
    private static func firstMetadataLine(at url: URL) throws -> String? {
        guard let handle = FileHandle(forReadingAtPath: url.path) else { return nil }
        defer { try? handle.close() }
        let chunkSize = 4096
        var buffer = Data()
        while buffer.firstIndex(of: UInt8(ascii: "\n")) == nil {
            let chunk = handle.readData(ofLength: chunkSize)
            if chunk.isEmpty { break }
            buffer.append(chunk)
        }
        let line: String?
        if let newlineIndex = buffer.firstIndex(of: UInt8(ascii: "\n")) {
            line = String(data: buffer[..<newlineIndex], encoding: .utf8)
        } else {
            line = String(data: buffer, encoding: .utf8)
        }
        guard let line, line.contains("\"_type\":\"metadata\"") else { return nil }
        return line
    }
}
