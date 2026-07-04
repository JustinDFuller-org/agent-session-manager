import Foundation
import OpenTelemetrySdk

/// Routes spans to per-pane JSONL files under `tracesDirectory`.
///
/// Spans with a `pane.id` attribute go to
///   `<tracesDirectory>/<tab.name>-<tab.id[..<8]>/<pane.name>-<pane.id[..<8]>.jsonl`
/// Spans without `pane.id` go to `<tracesDirectory>/_global/global.jsonl`.
///
/// Each file begins with a JSON metadata line (written once), followed by one span JSON
/// object per line. Files are trimmed from the top when they exceed `maxBytesPerFile`.
final class PerPaneSpanExporter: SpanExporter {
    let tracesDirectory: URL
    private let maxBytesPerFile: Int
    private let resourceAttributes: [String: String]
    private let queue = DispatchQueue(
        label: "com.justinfuller.agent-session-manager.per-pane-exporter",
        qos: .utility
    )
    // paneId (or "_global") → (fileURL, metadataWritten)
    private var writers: [String: (fileURL: URL, metadataWritten: Bool)] = [:]

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }()

    init(tracesDirectory: URL, maxBytesPerFile: Int, resourceAttributes: [String: String] = [:]) {
        self.tracesDirectory = tracesDirectory
        self.maxBytesPerFile = max(1_048_576, maxBytesPerFile)
        self.resourceAttributes = resourceAttributes
    }

    /// Metadata header written once per file, identifying the pane/tab and (for observability)
    /// the process-wide OTel resource attributes (service name/version, os/device info, ...).
    private struct MetadataLine: Encodable {
        let paneId: String
        let paneName: String
        let tabId: String
        let tabName: String
        let createdAt: String
        let resource: [String: String]

        enum CodingKeys: String, CodingKey {
            case type = "_type"
            case paneId, paneName, tabId, tabName, createdAt, resource
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode("metadata", forKey: .type)
            try container.encode(paneId, forKey: .paneId)
            try container.encode(paneName, forKey: .paneName)
            try container.encode(tabId, forKey: .tabId)
            try container.encode(tabName, forKey: .tabName)
            try container.encode(createdAt, forKey: .createdAt)
            try container.encode(resource, forKey: .resource)
        }
    }

    private struct SpanLine: Encodable {
        let name: String
        let traceId: String
        let spanId: String
        let parentSpanId: String?
        let startEpochMs: Int64
        let endEpochMs: Int64
        let durationMs: Int64
        let attributes: [String: String]

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(name, forKey: .name)
            try container.encode(traceId, forKey: .traceId)
            try container.encode(spanId, forKey: .spanId)
            try container.encodeIfPresent(parentSpanId, forKey: .parentSpanId)
            try container.encode(startEpochMs, forKey: .startEpochMs)
            try container.encode(endEpochMs, forKey: .endEpochMs)
            try container.encode(durationMs, forKey: .durationMs)
            try container.encode(attributes, forKey: .attributes)
        }

        enum CodingKeys: String, CodingKey {
            case name, traceId, spanId, parentSpanId, startEpochMs, endEpochMs, durationMs, attributes
        }
    }

    @discardableResult
    func export(spans: [SpanData], explicitTimeout: TimeInterval?) -> SpanExporterResultCode {
        // Group spans by pane.id attribute (or "_global" bucket)
        var groups: [String: [SpanData]] = [:]
        for span in spans {
            let key: String
            if case .string(let id) = span.attributes["pane.id"] {
                key = id
            } else {
                key = "_global"
            }
            groups[key, default: []].append(span)
        }

        for (key, groupSpans) in groups {
            let representative = groupSpans[0]
            let fileURL: URL
            if let existing = writers[key] {
                fileURL = existing.fileURL
            } else if key == "_global" {
                fileURL =
                    tracesDirectory
                    .appendingPathComponent("_global", isDirectory: true)
                    .appendingPathComponent("global.jsonl")
            } else {
                let tabId = attributeString(representative, "tab.id") ?? "unknown"
                let tabName = attributeString(representative, "tab.name") ?? "unknown"
                let paneName = attributeString(representative, "pane.name") ?? "unknown"
                let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_."))
                let tabDirName = "\(tabName)-\(String(tabId.prefix(8)))"
                    .components(separatedBy: allowed.inverted).joined(separator: "_")
                let fileName = "\(paneName)-\(String(key.prefix(8))).jsonl"
                    .components(separatedBy: allowed.inverted).joined(separator: "_")
                fileURL =
                    tracesDirectory
                    .appendingPathComponent(tabDirName, isDirectory: true)
                    .appendingPathComponent(fileName)
            }

            let needsMetadata = writers[key] == nil || !writers[key]!.metadataWritten
            var lines: [Data] = []
            if needsMetadata {
                let now = ISO8601DateFormatter().string(from: Date())
                let metadata: MetadataLine =
                    key == "_global"
                    ? MetadataLine(
                        paneId: "_global", paneName: "global", tabId: "_global", tabName: "_global",
                        createdAt: now, resource: resourceAttributes
                    )
                    : MetadataLine(
                        paneId: key,
                        paneName: attributeString(representative, "pane.name") ?? "",
                        tabId: attributeString(representative, "tab.id") ?? "",
                        tabName: attributeString(representative, "tab.name") ?? "",
                        createdAt: now,
                        resource: resourceAttributes
                    )
                if let data = try? Self.encoder.encode(metadata) {
                    lines.append(data)
                }
            }

            if writers[key] == nil {
                writers[key] = (fileURL: fileURL, metadataWritten: false)
            }
            writers[key]!.metadataWritten = true

            for span in groupSpans {
                let startMs = span.startTime.timeIntervalSince1970 * 1000
                let endMs = span.endTime.timeIntervalSince1970 * 1000
                let durationMs = endMs - startMs
                var attrs: [String: String] = [:]
                for (attrKey, value) in span.attributes {
                    switch value {
                    case .string(let str): attrs[attrKey] = str
                    case .bool(let bool): attrs[attrKey] = String(bool)
                    case .int(let int): attrs[attrKey] = String(int)
                    case .double(let double): attrs[attrKey] = String(double)
                    default: attrs[attrKey] = value.description
                    }
                }
                let parentSpanId = span.parentSpanId?.hexString
                let line = SpanLine(
                    name: span.name,
                    traceId: span.traceId.hexString,
                    spanId: span.spanId.hexString,
                    parentSpanId: (parentSpanId?.isEmpty ?? true) ? nil : parentSpanId,
                    startEpochMs: Int64(startMs),
                    endEpochMs: Int64(endMs),
                    durationMs: Int64(durationMs),
                    attributes: attrs
                )
                if let data = try? Self.encoder.encode(line) {
                    lines.append(data)
                }
            }

            guard !lines.isEmpty else { continue }
            let newline = Data([UInt8(ascii: "\n")])
            let payload = lines.reduce(into: Data()) { result, line in
                result.append(line)
                result.append(newline)
            }
            let maxBytes = maxBytesPerFile

            queue.async { [fileURL, payload] in
                let dir = fileURL.deletingLastPathComponent()
                try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                if !FileManager.default.fileExists(atPath: fileURL.path) {
                    FileManager.default.createFile(atPath: fileURL.path, contents: nil)
                }
                guard let handle = try? FileHandle(forWritingTo: fileURL) else { return }
                defer { try? handle.close() }
                do {
                    try handle.seekToEnd()
                    try handle.write(contentsOf: payload)
                } catch {
                    return
                }
                try? JSONLTrimmer.trimIfNeeded(
                    at: fileURL,
                    maxBytes: maxBytes,
                    marker: "--- [truncated older trace entries] ---"
                )
            }
        }
        return .success
    }

    @discardableResult
    func flush(explicitTimeout: TimeInterval?) -> SpanExporterResultCode { .success }

    func shutdown(explicitTimeout: TimeInterval?) {}

    // MARK: - Private helpers

    private func attributeString(_ span: SpanData, _ key: String) -> String? {
        guard case .string(let str) = span.attributes[key] else { return nil }
        return str
    }

    static func trimIfNeeded(at url: URL, maxBytes: Int) {
        try? JSONLTrimmer.trimIfNeeded(
            at: url,
            maxBytes: maxBytes,
            marker: "--- [truncated older trace entries] ---"
        )
    }
}
