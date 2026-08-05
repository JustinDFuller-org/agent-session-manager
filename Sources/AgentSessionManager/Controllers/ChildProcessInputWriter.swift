import Darwin
import Foundation

struct ChildProcessInputWriteFailure: Equatable, Sendable {
    enum Stage: String, Sendable {
        case configure
        case write
    }

    let stage: Stage
    let errorCode: Int32
}

final class ChildProcessExitState: @unchecked Sendable {
    let lock = NSLock()
    var status: Int32?
    var continuation: CheckedContinuation<Int32, Never>?
}

enum ChildProcessInputWriter {
    static func write(
        _ data: Data,
        to fileHandle: FileHandle,
        timeout: TimeInterval
    ) -> ChildProcessInputWriteFailure? {
        defer { try? fileHandle.close() }

        let descriptor = fileHandle.fileDescriptor
        guard fcntl(descriptor, F_SETNOSIGPIPE, 1) != -1 else {
            return ChildProcessInputWriteFailure(stage: .configure, errorCode: errno)
        }
        let currentFlags = fcntl(descriptor, F_GETFL)
        guard currentFlags != -1,
            fcntl(descriptor, F_SETFL, currentFlags | O_NONBLOCK) != -1
        else {
            return ChildProcessInputWriteFailure(stage: .configure, errorCode: errno)
        }
        guard !data.isEmpty else { return nil }
        let deadline = ProcessInfo.processInfo.systemUptime + max(0.001, timeout)
        return data.withUnsafeBytes { buffer in
            guard let baseAddress = buffer.baseAddress else { return nil }
            var offset = 0
            while offset < buffer.count {
                let bytesWritten = Darwin.write(
                    descriptor,
                    baseAddress.advanced(by: offset),
                    buffer.count - offset)
                if bytesWritten > 0 {
                    offset += bytesWritten
                    continue
                }
                if bytesWritten == -1, errno == EINTR {
                    continue
                }
                if bytesWritten == -1, errno == EAGAIN || errno == EWOULDBLOCK {
                    let remaining = deadline - ProcessInfo.processInfo.systemUptime
                    guard remaining > 0 else {
                        return ChildProcessInputWriteFailure(
                            stage: .write,
                            errorCode: ETIMEDOUT)
                    }
                    var pollDescriptor = pollfd(
                        fd: descriptor,
                        events: Int16(POLLOUT),
                        revents: 0)
                    let pollResult = Darwin.poll(
                        &pollDescriptor,
                        1,
                        Int32(min(remaining * 1_000, Double(Int32.max))))
                    if pollResult > 0 {
                        continue
                    }
                    if pollResult == -1, errno == EINTR {
                        continue
                    }
                    return ChildProcessInputWriteFailure(
                        stage: .write,
                        errorCode: pollResult == 0 ? ETIMEDOUT : errno)
                }
                return ChildProcessInputWriteFailure(
                    stage: .write,
                    errorCode: bytesWritten == -1 ? errno : EIO)
            }
            return nil
        }
    }
}
