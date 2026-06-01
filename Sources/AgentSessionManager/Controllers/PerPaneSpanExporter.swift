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
    private let queue = DispatchQueue(
        label: "com.justinfuller.agent-session-manager.per-pane-exporter",
        qos: .utility
    )
    // paneId (or "_global") → (fileURL, metadataWritten)
    private var writers: [String: (fileURL: URL, metadataWritten: Bool)] = [:]

    init(tracesDirectory: URL, maxBytesPerFile: Int) {
        self.tracesDirectory = tracesDirectory
        self.maxBytesPerFile = max(1_048_576, maxBytesPerFile)
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
            let metadataLine: String?
            if needsMetadata {
                let now = ISO8601DateFormatter().string(from: Date())
                if key == "_global" {
                    metadataLine =
                        """
                        {"_type":"metadata","paneId":"_global","paneName":"global","tabId":"_global","tabName":"_global","createdAt":"\(now)"}
                        """
                } else {
                    let tabId = attributeString(representative, "tab.id") ?? ""
                    let tabName = attributeString(representative, "tab.name") ?? ""
                    let paneName = attributeString(representative, "pane.name") ?? ""
                    metadataLine =
                        """
                        {"_type":"metadata","paneId":"\(jsonEscape(key))","paneName":"\(jsonEscape(paneName))","tabId":"\(jsonEscape(tabId))","tabName":"\(jsonEscape(tabName))","createdAt":"\(now)"}
                        """
                }
            } else {
                metadataLine = nil
            }

            if writers[key] == nil {
                writers[key] = (fileURL: fileURL, metadataWritten: false)
            }
            writers[key]!.metadataWritten = true

            let spanLines = groupSpans.map { span in
                let startMs = span.startTime.timeIntervalSince1970 * 1000
                let endMs = span.endTime.timeIntervalSince1970 * 1000
                let durationMs = endMs - startMs
                var attrs: [String: String] = [:]
                for (key, value) in span.attributes {
                    switch value {
                    case .string(let str): attrs[key] = str
                    case .bool(let bool): attrs[key] = String(bool)
                    case .int(let int): attrs[key] = String(int)
                    case .double(let double): attrs[key] = String(double)
                    default: attrs[key] = value.description
                    }
                }
                let attrsJSON =
                    attrs.isEmpty
                    ? "{}"
                    : "{\(attrs.sorted { $0.key < $1.key }.map { "\"\(jsonEscape($0.key))\":\"\(jsonEscape($0.value))\"" }.joined(separator: ","))}"
                let parentSpanId = span.parentSpanId?.hexString ?? ""
                let parentField = parentSpanId.isEmpty ? "" : ",\"parentSpanId\":\"\(parentSpanId)\""
                return """
                    {"name":"\(jsonEscape(span.name))","traceId":"\(span.traceId.hexString)","spanId":"\(span.spanId.hexString)"\(parentField),"startEpochMs":\(Int64(startMs)),"endEpochMs":\(Int64(endMs)),"durationMs":\(Int64(durationMs)),"attributes":\(attrsJSON)}
                    """
            }
            guard !spanLines.isEmpty || metadataLine != nil else { continue }

            var payload = ""
            if let meta = metadataLine { payload += meta + "\n" }
            if !spanLines.isEmpty { payload += spanLines.joined(separator: "\n") + "\n" }
            let data = Data(payload.utf8)
            let maxBytes = maxBytesPerFile

            queue.async { [fileURL] in
                let dir = fileURL.deletingLastPathComponent()
                try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                if !FileManager.default.fileExists(atPath: fileURL.path) {
                    FileManager.default.createFile(atPath: fileURL.path, contents: nil)
                }
                guard let handle = try? FileHandle(forWritingTo: fileURL) else { return }
                defer { try? handle.close() }
                do {
                    try handle.seekToEnd()
                    try handle.write(contentsOf: data)
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

    private func jsonEscape(_ str: String) -> String {
        str.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "\t", with: "\\t")
    }

    static func trimIfNeeded(at url: URL, maxBytes: Int) {
        try? JSONLTrimmer.trimIfNeeded(
            at: url,
            maxBytes: maxBytes,
            marker: "--- [truncated older trace entries] ---"
        )
    }
}
