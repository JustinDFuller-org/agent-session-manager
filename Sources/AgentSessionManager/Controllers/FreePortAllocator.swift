import Foundation
import Network

final class FreePortAllocator {
    private final class AllocationState: @unchecked Sendable {
        let lock = NSLock()
        var port: Int?
    }

    static func allocate(timeout: TimeInterval = 2) -> Int? {
        let semaphore = DispatchSemaphore(value: 0)
        let allocation = AllocationState()

        let listener: NWListener
        do {
            listener = try NWListener(using: .tcp)
        } catch {
            return nil
        }

        listener.newConnectionHandler = { _ in }

        listener.stateUpdateHandler = { [weak listener] state in
            guard let listener else {
                semaphore.signal()
                return
            }
            switch state {
            case .ready:
                if let port = listener.port {
                    allocation.lock.withLock {
                        allocation.port = Int(port.rawValue)
                    }
                }
                listener.cancel()
                semaphore.signal()
            case .failed, .cancelled:
                semaphore.signal()
            default:
                break
            }
        }

        listener.start(queue: .global(qos: .utility))
        _ = semaphore.wait(timeout: .now() + timeout)
        let allocatedPort = allocation.lock.withLock { allocation.port }
        if allocatedPort == nil { listener.cancel() }

        return allocatedPort
    }
}
