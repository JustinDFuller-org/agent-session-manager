import Foundation

/// Bounds a subprocess pipe read taken after the process has already terminated. A child that
/// leaves a grandchild holding the pipe's write end open never signals EOF, so
/// `FileHandle.readDataToEndOfFile()` can block forever even though the process it belongs to has
/// already exited. Racing that read against a deadline on a separate thread keeps the calling
/// flow (a continuation, a polling loop, a status-line refresh) from hanging forever — the
/// abandoned reader thread and its two file descriptors cannot be reclaimed without killing the
/// whole process tree, but at least the occurrence becomes visible instead of silent.
enum ChildProcessOutputReader {
    static let defaultTimeout: TimeInterval = 2

    private final class Box<Value>: @unchecked Sendable {
        var value: Value
        init(_ value: Value) { self.value = value }
    }

    /// `site` identifies the call site in the emitted span/invariant context, so a stuck child
    /// is traceable back to the code path that spawned it.
    static func readToEndOfFile(
        _ handle: FileHandle,
        site: String,
        timeout: TimeInterval = defaultTimeout
    ) -> Data {
        let semaphore = DispatchSemaphore(value: 0)
        let box = Box(Data())
        DispatchQueue.global(qos: .utility).async {
            box.value = handle.readDataToEndOfFile()
            semaphore.signal()
        }
        guard semaphore.wait(timeout: .now() + timeout) == .success else {
            TracingService.shared.record(
                "process.output_read.timed_out",
                attributes: ["site": site, "timeout_seconds": String(timeout)]
            )
            InvariantReporter.shared.violated(.childProcessOutputReadBounded, context: ["site": site])
            return Data()
        }
        return box.value
    }
}
