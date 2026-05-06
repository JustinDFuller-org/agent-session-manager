import Foundation
import Observation

enum SidebarSide: String, Codable, CaseIterable {
    case left, right

    var displayName: String {
        switch self {
        case .left: return "Left"
        case .right: return "Right"
        }
    }
}

@Observable
@MainActor
final class StatusLineMonitor {
    private(set) var currentData: StatusLineData?

    let filePath: String
    let settingsFilePath: String
    private var source: DispatchSourceFileSystemObject?

    init(paneID: UUID) {
        filePath = NSTemporaryDirectory() + "agent-session-manager-status-\(paneID.uuidString).json"
        settingsFilePath = NSTemporaryDirectory() + "agent-session-manager-settings-\(paneID.uuidString).json"
    }

    func start() {
        writeSettingsFile()
        FileManager.default.createFile(atPath: filePath, contents: nil)

        let fd = open(filePath, O_EVTONLY)
        guard fd >= 0 else { return }

        let src = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .extend],
            queue: .global(qos: .utility)
        )
        src.setEventHandler { [weak self, filePath] in
            guard let data = try? Data(contentsOf: URL(filePath: filePath)),
                  let parsed = try? JSONDecoder().decode(StatusLineData.self, from: data)
            else { return }
            Task { @MainActor [weak self] in
                self?.currentData = parsed
            }
        }
        src.setCancelHandler { close(fd) }
        src.resume()
        source = src
    }

    func stop() {
        source?.cancel()
        source = nil
        try? FileManager.default.removeItem(atPath: filePath)
        try? FileManager.default.removeItem(atPath: settingsFilePath)
    }

    private func writeSettingsFile() {
        let settings: [String: Any] = [
            "statusLine": [
                "type": "command",
                "command": "cat > '\(filePath)'"
            ]
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: settings, options: .prettyPrinted) else { return }
        try? data.write(to: URL(filePath: settingsFilePath))
    }
}
