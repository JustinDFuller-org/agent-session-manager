import Foundation

/// Deletes per-pane JSONL files older than `retentionInterval` and removes empty
/// subdirectories. Runs once on `start()` and then every 6 hours on a background timer.
final class TraceCleanupService {
    private let tracesDirectory: URL
    private let retentionInterval: TimeInterval
    private var timer: Timer?

    init(tracesDirectory: URL, retentionInterval: TimeInterval = 24 * 3600) {
        self.tracesDirectory = tracesDirectory
        self.retentionInterval = retentionInterval
    }

    func start() {
        runCleanup()
        timer = Timer.scheduledTimer(withTimeInterval: 6 * 3600, repeats: true) { [weak self] _ in
            self?.runCleanup()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func runCleanup() {
        let dir = tracesDirectory
        let cutoff = retentionInterval
        DispatchQueue.global(qos: .utility).async {
            let (filesDeleted, dirsRemoved) = Self.cleanup(in: dir, olderThan: cutoff)
            TracingService.shared.record(
                "trace.cleanup.ran",
                attributes: [
                    "files_deleted": "\(filesDeleted)",
                    "dirs_removed": "\(dirsRemoved)",
                ])
        }
    }

    static func cleanup(
        in directory: URL, olderThan retentionInterval: TimeInterval
    ) -> (filesDeleted: Int, dirsRemoved: Int) {
        let fm = FileManager.default
        let now = Date()
        var filesDeleted = 0
        var dirsRemoved = 0

        guard
            let subDirs = try? fm.contentsOfDirectory(
                at: directory, includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )
        else { return (0, 0) }

        for subDir in subDirs {
            guard (try? subDir.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true else { continue }

            guard
                let files = try? fm.contentsOfDirectory(
                    at: subDir, includingPropertiesForKeys: [.contentModificationDateKey],
                    options: [.skipsHiddenFiles]
                )
            else { continue }

            for file in files {
                guard file.pathExtension == "jsonl" else { continue }
                guard
                    let attrs = try? fm.attributesOfItem(atPath: file.path),
                    let mtime = attrs[.modificationDate] as? Date
                else { continue }
                if now.timeIntervalSince(mtime) > retentionInterval {
                    if (try? fm.removeItem(at: file)) != nil {
                        filesDeleted += 1
                    }
                }
            }

            // Remove subdirectory if now empty
            let remaining = (try? fm.contentsOfDirectory(atPath: subDir.path)) ?? []
            if remaining.isEmpty {
                if (try? fm.removeItem(at: subDir)) != nil {
                    dirsRemoved += 1
                }
            }
        }

        return (filesDeleted, dirsRemoved)
    }
}
