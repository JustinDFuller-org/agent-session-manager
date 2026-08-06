import Darwin
import Foundation

enum ApplicationLifecycleState: String, Codable, Sendable {
    case running
    case clean
}

enum PreviousApplicationExit: String, Sendable {
    case clean
    case unclean
    case unknown
}

enum ApplicationLifecycleMarkerWriteResult: String, Sendable {
    case written
    case ownershipMismatch = "ownership_mismatch"
    case writeFailed = "write_failed"
}

struct ApplicationLifecycleRecordResult: Sendable {
    let previousExit: PreviousApplicationExit
    let writeResult: ApplicationLifecycleMarkerWriteResult
}

enum ApplicationLifecycleMarker {
    private struct Marker: Codable {
        let schemaVersion: Int
        let state: ApplicationLifecycleState
        let launchID: UUID
        let timestamp: Date
    }

    @discardableResult
    static func record(
        _ state: ApplicationLifecycleState,
        launchID: UUID
    ) -> ApplicationLifecycleRecordResult {
        let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let directoryURL = baseURL.appending(path: PersistenceHelpers.appSupportSubdirectory)
        let markerURL = directoryURL.appending(path: "app-lifecycle.json")
        do {
            try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        } catch {
            return ApplicationLifecycleRecordResult(
                previousExit: .unknown,
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
        case nil:
            previousExit = .unknown
        }
        if state == .clean, previousMarker?.launchID != launchID {
            return ApplicationLifecycleRecordResult(
                previousExit: previousExit,
                writeResult: .ownershipMismatch)
        }

        do {
            let data = try JSONEncoder().encode(
                Marker(schemaVersion: 1, state: state, launchID: launchID, timestamp: Date()))
            try data.write(to: markerURL, options: .atomic)
            return ApplicationLifecycleRecordResult(
                previousExit: previousExit,
                writeResult: .written)
        } catch {
            return ApplicationLifecycleRecordResult(
                previousExit: previousExit,
                writeResult: .writeFailed)
        }
    }
}
