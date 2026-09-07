import Foundation
import Observation

struct StoredSpan: Identifiable {
    let id: UUID
    let name: String
    let traceId: String
    let spanId: String
    let parentSpanId: String?
    let startEpochMs: Int64
    let endEpochMs: Int64
    let durationMs: Int64
    let attributes: [String: String]

    init(
        name: String,
        traceId: String,
        spanId: String,
        parentSpanId: String?,
        startEpochMs: Int64,
        endEpochMs: Int64,
        attributes: [String: String]
    ) {
        self.id = UUID()
        self.name = name
        self.traceId = traceId
        self.spanId = spanId
        self.parentSpanId = parentSpanId
        self.startEpochMs = startEpochMs
        self.endEpochMs = endEpochMs
        self.durationMs = endEpochMs - startEpochMs
        self.attributes = attributes
    }
}

struct TraceTab: Identifiable {
    let id: String
    let name: String
    var panes: [TracePane]
}

struct TracePane: Identifiable {
    let id: String
    let name: String
    let fileURL: URL
}

@Observable
@MainActor
final class TraceRepository {
    var tabs: [TraceTab] = []
    var selectedPaneURL: URL?
    var selectedPaneSpans: [StoredSpan] = []

    private let tracesDirectory: URL
    private var fileWatcher: FileSystemEventWatcher?

    init(tracesDirectory: URL) {
        self.tracesDirectory = tracesDirectory
    }

    func refresh() {
        var newTabs: [TraceTab] = []
        let fm = FileManager.default

        guard
            let tabDirs = try? fm.contentsOfDirectory(
                at: tracesDirectory, includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )
        else {
            tabs = []
            return
        }

        var globalTab: TraceTab?

        for tabDir in tabDirs.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            guard (try? tabDir.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true else { continue }
            let dirName = tabDir.lastPathComponent

            if dirName == "_global" {
                let globalFile = tabDir.appendingPathComponent("global.jsonl")
                if fm.fileExists(atPath: globalFile.path) {
                    let pane = TracePane(id: "global", name: "Global", fileURL: globalFile)
                    globalTab = TraceTab(id: "_global", name: "Global", panes: [pane])
                }
                continue
            }

            guard
                let paneFiles = try? fm.contentsOfDirectory(
                    at: tabDir, includingPropertiesForKeys: nil,
                    options: [.skipsHiddenFiles]
                )
            else { continue }

            let jsonlFiles = paneFiles.filter { $0.pathExtension == "jsonl" }
                .sorted { $0.lastPathComponent < $1.lastPathComponent }
            guard !jsonlFiles.isEmpty else { continue }

            let dirParts = dirName.components(separatedBy: "-")
            let tabName =
                dirParts.count >= 2 && dirParts.last?.count == 8
                ? dirParts.dropLast().joined(separator: "-") : dirName
            let tabId = dirParts.count >= 2 ? dirParts.last ?? dirName : dirName

            var panes: [TracePane] = []
            for paneFile in jsonlFiles {
                var meta: [String: String]?
                if let handle = try? FileHandle(forReadingFrom: paneFile) {
                    defer { try? handle.close() }
                    let chunk = (try? handle.read(upToCount: 4096)) ?? Data()
                    if let text = String(data: chunk, encoding: .utf8) {
                        let firstLine = text.components(separatedBy: "\n").first ?? ""
                        if let data = firstLine.data(using: .utf8),
                            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                            (json["_type"] as? String) == "metadata"
                        {
                            var values: [String: String] = [:]
                            for (key, value) in json {
                                if let string = value as? String { values[key] = string }
                            }
                            meta = values
                        }
                    }
                }
                let paneId = meta?["paneId"] ?? paneFile.deletingPathExtension().lastPathComponent
                let filename = paneFile.deletingPathExtension().lastPathComponent
                let parts = filename.components(separatedBy: "-")
                let fallbackName =
                    parts.count >= 2 && parts.last?.count == 8
                    ? parts.dropLast().joined(separator: "-") : filename
                let paneName = meta?["paneName"] ?? fallbackName
                panes.append(TracePane(id: paneId, name: paneName, fileURL: paneFile))
            }

            newTabs.append(TraceTab(id: tabId, name: tabName, panes: panes))
        }

        if let global = globalTab { newTabs.append(global) }
        tabs = newTabs
    }

    func selectPane(_ url: URL) {
        fileWatcher?.cancel()
        fileWatcher = nil
        selectedPaneURL = url
        selectedPaneSpans = []
        loadSpans(from: url)
        fileWatcher = FileSystemEventWatcher(
            url: url,
            followsReplacement: true,
            onEvent: { [weak self, url] _ in
                guard let self, selectedPaneURL == url else { return }
                loadSpans(from: url)
            },
            onStateChange: { [weak self, url] state in
                guard let self, selectedPaneURL == url,
                    case .waitingForFile = state
                else { return }
                selectedPaneSpans = []
            }
        )
        fileWatcher?.start()
    }

    func loadSpans(from url: URL) {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return }
        selectedPaneSpans = Self.parseSpans(from: content)
    }

    static func parseSpans(from content: String) -> [StoredSpan] {
        var result: [StoredSpan] = []
        for line in content.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            guard let data = trimmed.data(using: .utf8),
                let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            else { continue }
            if (json["_type"] as? String) == "metadata" { continue }
            guard let name = json["name"] as? String,
                let traceId = json["traceId"] as? String,
                let spanId = json["spanId"] as? String,
                let startMs = json["startEpochMs"] as? Int64 ?? (json["startEpochMs"] as? Double).map(Int64.init),
                let endMs = json["endEpochMs"] as? Int64 ?? (json["endEpochMs"] as? Double).map(Int64.init)
            else { continue }
            let parentSpanId = json["parentSpanId"] as? String
            let rawAttrs = json["attributes"] as? [String: String] ?? [:]
            result.append(
                StoredSpan(
                    name: name, traceId: traceId, spanId: spanId, parentSpanId: parentSpanId,
                    startEpochMs: startMs, endEpochMs: endMs, attributes: rawAttrs
                ))
        }
        return result
    }
}
