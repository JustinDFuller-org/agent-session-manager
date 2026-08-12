import Foundation

/// Deletes per-pane and invariant JSONL files (including rotated `.1.jsonl` generations) older
/// than `retentionInterval`, reclaims orphaned atomic-write temporaries (`*.sb-*`) and the legacy
/// root-level `debug-trace.log`/`traces.jsonl` files, and removes empty subdirectories. Runs once
/// on initialization and then every 6 hours on a background timer.
@MainActor
final class TraceCleanupService {
    private let tracesDirectory: URL
    private let retentionInterval: TimeInterval
    private var timer: Timer?

    init(tracesDirectory: URL, retentionInterval: TimeInterval = 24 * 3600) {
        self.tracesDirectory = tracesDirectory
        self.retentionInterval = retentionInterval
        runCleanup()
        timer = Timer.scheduledTimer(withTimeInterval: 6 * 3600, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.runCleanup()
            }
        }
    }

    private func runCleanup() {
        let dir = tracesDirectory
        let cutoff = retentionInterval
        DispatchQueue.global(qos: .utility).async {
            let (filesDeleted, dirsRemoved) = Self.cleanup(in: dir, olderThan: cutoff)
            let invariantsDeleted = Self.cleanupFlatDirectory(
                at: dir.deletingLastPathComponent().appending(path: "invariants"), olderThan: cutoff)
            let legacyReclaimed = Self.reclaimLegacyRootFiles(supportDirectory: dir.deletingLastPathComponent())
            TracingService.shared.record(
                "trace.cleanup.ran",
                attributes: [
                    "files_deleted": "\(filesDeleted)",
                    "dirs_removed": "\(dirsRemoved)",
                    "invariant_files_deleted": "\(invariantsDeleted)",
                    "legacy_files_reclaimed": "\(legacyReclaimed)",
                ])
        }
    }

    /// Threshold for reclaiming an orphaned atomic-write temporary (`*.sb-*`, left behind when a
    /// process died between `Data.write(options: .atomic)`'s temp-file write and its rename). Far
    /// shorter than `retentionInterval` since a real orphan is always already stale; the margin
    /// only guards against catching a write that's genuinely still in flight.
    private nonisolated static let atomicWriteTempStaleInterval: TimeInterval = 300

    private nonisolated static func isReclaimable(_ file: URL, now: Date, retentionInterval: TimeInterval) -> Bool {
        let isOrphanedAtomicWriteTemp = file.lastPathComponent.contains(".sb-")
        guard file.pathExtension == "jsonl" || isOrphanedAtomicWriteTemp else { return false }
        guard
            let attrs = try? FileManager.default.attributesOfItem(atPath: file.path),
            let mtime = attrs[.modificationDate] as? Date
        else { return false }
        let staleAfter = isOrphanedAtomicWriteTemp ? atomicWriteTempStaleInterval : retentionInterval
        return now.timeIntervalSince(mtime) > staleAfter
    }

    nonisolated static func cleanup(
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
                guard isReclaimable(file, now: now, retentionInterval: retentionInterval) else { continue }
                if (try? fm.removeItem(at: file)) != nil {
                    filesDeleted += 1
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

    /// Same reclaim rules as ``cleanup(in:olderThan:)``, for a directory with no per-pane
    /// subdirectory nesting (`invariants/` holds its JSONL files directly).
    nonisolated static func cleanupFlatDirectory(at directory: URL, olderThan retentionInterval: TimeInterval) -> Int {
        let fm = FileManager.default
        let now = Date()
        var filesDeleted = 0

        guard
            let files = try? fm.contentsOfDirectory(
                at: directory, includingPropertiesForKeys: [.contentModificationDateKey],
                options: [.skipsHiddenFiles]
            )
        else { return 0 }

        for file in files {
            guard isReclaimable(file, now: now, retentionInterval: retentionInterval) else { continue }
            if (try? fm.removeItem(at: file)) != nil {
                filesDeleted += 1
            }
        }
        return filesDeleted
    }

    /// `debug-trace.log` and `traces.jsonl` are legacy formats nothing in the current app writes;
    /// `AgentControlDiagnostics` reports them but never deletes them.
    nonisolated static func reclaimLegacyRootFiles(supportDirectory: URL) -> Int {
        var reclaimed = 0
        for name in ["debug-trace.log", "traces.jsonl"] {
            let url = supportDirectory.appending(path: name)
            guard FileManager.default.fileExists(atPath: url.path) else { continue }
            if (try? FileManager.default.removeItem(at: url)) != nil {
                reclaimed += 1
            }
        }
        return reclaimed
    }
}
