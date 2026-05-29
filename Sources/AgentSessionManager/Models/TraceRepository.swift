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
    private var fileWatchSource: DispatchSourceFileSystemObject?
    private var fileWatchFD: Int32 = -1

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

            // Read metadata from the first .jsonl file to get tab name
            guard
                let paneFiles = try? fm.contentsOfDirectory(
                    at: tabDir, includingPropertiesForKeys: nil,
                    options: [.skipsHiddenFiles]
                )
            else { continue }

            let jsonlFiles = paneFiles.filter { $0.pathExtension == "jsonl" }
                .sorted { $0.lastPathComponent < $1.lastPathComponent }
            guard !jsonlFiles.isEmpty else { continue }

            // Derive tab name from directory name (strip the -<tabId8> suffix if possible)
            let tabName = tabNameFromDirName(dirName)
            let tabId = tabIdFromDirName(dirName) ?? dirName

            var panes: [TracePane] = []
            for paneFile in jsonlFiles {
                let meta = readMetadata(from: paneFile)
                let paneId = meta?["paneId"] ?? paneFile.deletingPathExtension().lastPathComponent
                let paneName = meta?["paneName"] ?? paneNameFromFileName(paneFile.deletingPathExtension().lastPathComponent)
                panes.append(TracePane(id: paneId, name: paneName, fileURL: paneFile))
            }

            newTabs.append(TraceTab(id: tabId, name: tabName, panes: panes))
        }

        if let global = globalTab { newTabs.append(global) }
        tabs = newTabs
    }

    func selectPane(_ url: URL) {
        stopFileWatch()
        selectedPaneURL = url
        loadSpans(from: url)
        startFileWatch(url: url)
    }

    func clearSelection() {
        stopFileWatch()
        selectedPaneURL = nil
        selectedPaneSpans = []
    }

    // MARK: - JSONL loading

    func loadSpans(from url: URL) {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else {
            selectedPaneSpans = []
            return
        }
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
            // Skip metadata lines and truncation markers
            if (json["_type"] as? String) == "metadata" { continue }
            guard let name = json["name"] as? String,
                  let traceId = json["traceId"] as? String,
                  let spanId = json["spanId"] as? String,
                  let startMs = json["startEpochMs"] as? Int64 ?? (json["startEpochMs"] as? Double).map(Int64.init),
                  let endMs = json["endEpochMs"] as? Int64 ?? (json["endEpochMs"] as? Double).map(Int64.init)
            else { continue }
            let parentSpanId = json["parentSpanId"] as? String
            let rawAttrs = json["attributes"] as? [String: String] ?? [:]
            result.append(StoredSpan(
                name: name, traceId: traceId, spanId: spanId, parentSpanId: parentSpanId,
                startEpochMs: startMs, endEpochMs: endMs, attributes: rawAttrs
            ))
        }
        return result
    }

    // MARK: - File watching

    private func startFileWatch(url: URL) {
        let fd = open(url.path, O_EVTONLY)
        guard fd >= 0 else { return }
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .extend],
            queue: .global(qos: .utility)
        )
        source.setEventHandler { [weak self, url] in
            Task { @MainActor [weak self] in
                guard let self, self.selectedPaneURL == url else { return }
                self.loadSpans(from: url)
            }
        }
        source.setCancelHandler { close(fd) }
        source.resume()
        fileWatchSource = source
        fileWatchFD = fd
    }

    private func stopFileWatch() {
        fileWatchSource?.cancel()
        fileWatchSource = nil
        fileWatchFD = -1
    }

    // MARK: - Filename helpers

    private func readMetadata(from url: URL) -> [String: String]? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        // Read up to 4 KB to find the first line
        let chunk = (try? handle.read(upToCount: 4096)) ?? Data()
        guard let text = String(data: chunk, encoding: .utf8) else { return nil }
        let firstLine = text.components(separatedBy: "\n").first ?? ""
        guard let data = firstLine.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              (json["_type"] as? String) == "metadata"
        else { return nil }
        var result: [String: String] = [:]
        for (k, v) in json { if let s = v as? String { result[k] = s } }
        return result
    }

    private func tabNameFromDirName(_ name: String) -> String {
        // Directory name format: <tabName>-<tabId8> — strip the last "-<8hex>" suffix
        let parts = name.components(separatedBy: "-")
        guard parts.count >= 2, parts.last?.count == 8 else { return name }
        return parts.dropLast().joined(separator: "-")
    }

    private func tabIdFromDirName(_ name: String) -> String? {
        let parts = name.components(separatedBy: "-")
        guard parts.count >= 2 else { return nil }
        return parts.last
    }

    private func paneNameFromFileName(_ name: String) -> String {
        let parts = name.components(separatedBy: "-")
        guard parts.count >= 2, parts.last?.count == 8 else { return name }
        return parts.dropLast().joined(separator: "-")
    }
}
