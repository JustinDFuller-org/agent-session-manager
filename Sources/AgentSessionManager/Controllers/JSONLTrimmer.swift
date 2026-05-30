import Foundation

enum JSONLTrimmer {
    static func trimIfNeeded(at url: URL, maxBytes: Int, marker: String, preserveMetadata: Bool = false) throws {
        let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
        guard let size = (attrs[.size] as? NSNumber)?.intValue, size > maxBytes else { return }
        let existing = try Data(contentsOf: url)
        guard !existing.isEmpty else { return }

        let markerData = Data((marker + "\n").utf8)
        let metadataData: Data
        if preserveMetadata,
            let metadataLine = String(data: existing, encoding: .utf8)?
                .components(separatedBy: "\n")
                .first(where: { $0.contains("\"_type\":\"metadata\"") })
        {
            metadataData = Data((metadataLine + "\n").utf8)
        } else {
            metadataData = Data()
        }
        let targetKeep = max(0, maxBytes - markerData.count - metadataData.count)
        var cut = max(0, existing.count - targetKeep)
        while cut < existing.count, existing[cut] != UInt8(ascii: "\n") { cut += 1 }
        if cut < existing.count { cut += 1 }

        var newData = markerData
        newData.append(metadataData)
        if cut < existing.count { newData.append(existing[cut...]) }
        try newData.write(to: url, options: .atomic)
    }
}
