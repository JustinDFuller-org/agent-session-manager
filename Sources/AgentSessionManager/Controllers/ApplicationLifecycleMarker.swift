import Darwin
import Foundation

enum ApplicationLifecycleState: String, Codable, Sendable {
    case running
    case terminating
    case clean
}

enum PreviousApplicationExit: String, Sendable {
    case clean
    case unclean
    case uncleanDuringTeardown = "unclean_during_teardown"
    case unknown
}

enum ApplicationLifecycleMarkerWriteResult: String, Sendable {
    case written
    case ownershipMismatch = "ownership_mismatch"
    case writeFailed = "write_failed"
}

struct ApplicationLifecycleRecordResult: Sendable {
    let previousExit: PreviousApplicationExit
    let previousHeartbeatAt: Date?
    let previousPeakFootprintBytes: Int64?
    let writeResult: ApplicationLifecycleMarkerWriteResult
}

enum ApplicationLifecycleMarker {
    private struct Marker: Codable {
        let schemaVersion: Int
        let state: ApplicationLifecycleState
        let launchID: UUID
        let timestamp: Date
        var peakFootprintBytes: Int64?
    }

    /// Current resident footprint (`task_vm_info.phys_footprint`), the same figure Activity
    /// Monitor's "Memory" column reports. `nil` only if the kernel call itself fails.
    static func currentFootprintBytes() -> Int64? {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &info) { pointer -> kern_return_t in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { reboundPointer in
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), reboundPointer, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }
        return Int64(info.phys_footprint)
    }

    @discardableResult
    static func record(
        _ state: ApplicationLifecycleState,
        launchID: UUID,
        footprintBytes: Int64? = nil
    ) -> ApplicationLifecycleRecordResult {
        let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let directoryURL = baseURL.appending(path: PersistenceHelpers.appSupportSubdirectory)
        let markerURL = directoryURL.appending(path: "app-lifecycle.json")
        do {
            try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        } catch {
            return ApplicationLifecycleRecordResult(
                previousExit: .unknown,
                previousHeartbeatAt: nil,
                previousPeakFootprintBytes: nil,
                writeResult: .writeFailed)
        }
        let lockFD = open(
            directoryURL.appending(path: "app-lifecycle.lock").path,
            O_CREAT | O_RDWR,
            0o600)
        guard lockFD >= 0, flock(lockFD, LOCK_EX) == 0 else {
            if lockFD >= 0 { close(lockFD) }
            return ApplicationLifecycleRecordResult(
                previousExit: .unknown,
                previousHeartbeatAt: nil,
                previousPeakFootprintBytes: nil,
                writeResult: .writeFailed)
        }
        defer {
            flock(lockFD, LOCK_UN)
            close(lockFD)
        }

        let previousMarker: Marker?
        if let previousData = try? Data(contentsOf: markerURL) {
            let decoded = try? JSONDecoder().decode(Marker.self, from: previousData)
            previousMarker = decoded?.schemaVersion == 1 ? decoded : nil
        } else {
            previousMarker = nil
        }
        let previousExit: PreviousApplicationExit
        switch previousMarker?.state {
        case .clean:
            previousExit = .clean
        case .running:
            previousExit = .unclean
        case .terminating:
            previousExit = .uncleanDuringTeardown
        case nil:
            previousExit = .unknown
        }
        if state != .running, previousMarker?.launchID != launchID {
            return ApplicationLifecycleRecordResult(
                previousExit: previousExit,
                previousHeartbeatAt: previousMarker?.timestamp,
                previousPeakFootprintBytes: previousMarker?.peakFootprintBytes,
                writeResult: .ownershipMismatch)
        }

        let peakFootprintBytes: Int64? = [previousMarker?.peakFootprintBytes, footprintBytes]
            .compactMap { $0 }
            .max()

        do {
            let data = try JSONEncoder().encode(
                Marker(
                    schemaVersion: 1, state: state, launchID: launchID, timestamp: Date(),
                    peakFootprintBytes: peakFootprintBytes))
            try data.write(to: markerURL, options: .atomic)
            return ApplicationLifecycleRecordResult(
                previousExit: previousExit,
                previousHeartbeatAt: previousMarker?.timestamp,
                previousPeakFootprintBytes: previousMarker?.peakFootprintBytes,
                writeResult: .written)
        } catch {
            return ApplicationLifecycleRecordResult(
                previousExit: previousExit,
                previousHeartbeatAt: previousMarker?.timestamp,
                previousPeakFootprintBytes: previousMarker?.peakFootprintBytes,
                writeResult: .writeFailed)
        }
    }
}
