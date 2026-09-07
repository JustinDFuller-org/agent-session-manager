import Darwin
import Foundation

@MainActor
final class FileSystemEventWatcher {
    enum Event: Equatable, Sendable {
        case contentChanged
        case fileAvailable
        case fileReplaced
    }

    enum StateChange: Sendable {
        case started
        case waitingForFile(errno: Int32)
        case recovered
        case stopped
    }

    private let url: URL
    private let contentEvents: DispatchSource.FileSystemEvent
    private let followsReplacement: Bool
    private let retryDelay: Duration
    private let onEvent: @MainActor (Event) -> Void
    private let onStateChange: (@MainActor (StateChange) -> Void)?
    private var source: DispatchSourceFileSystemObject?
    private var retryTask: Task<Void, Never>?
    private var generation = 0
    private var hasAttached = false
    private var waitingErrno: Int32?
    private var pendingReplacementDelivery = false
    private var isStarted = false

    init(
        url: URL,
        contentEvents: DispatchSource.FileSystemEvent = [.write, .extend],
        followsReplacement: Bool,
        retryDelay: Duration = .milliseconds(100),
        onEvent: @escaping @MainActor (Event) -> Void,
        onStateChange: (@MainActor (StateChange) -> Void)? = nil
    ) {
        self.url = url
        self.contentEvents = contentEvents
        self.followsReplacement = followsReplacement
        self.retryDelay = retryDelay
        self.onEvent = onEvent
        self.onStateChange = onStateChange
    }

    deinit {
        retryTask?.cancel()
        source?.cancel()
    }

    func start() {
        guard !isStarted else { return }
        isStarted = true
        hasAttached = false
        waitingErrno = nil
        pendingReplacementDelivery = false
        generation += 1
        attach(generation: generation)
    }

    func cancel() {
        guard isStarted || source != nil || retryTask != nil else { return }
        isStarted = false
        generation += 1
        retryTask?.cancel()
        retryTask = nil
        source?.cancel()
        source = nil
        waitingErrno = nil
        pendingReplacementDelivery = false
        onStateChange?(.stopped)
    }

    private func attach(generation expectedGeneration: Int) {
        guard isStarted, generation == expectedGeneration, source == nil else { return }
        retryTask?.cancel()
        retryTask = nil

        let fileDescriptor = open(url.path, O_EVTONLY)
        guard fileDescriptor >= 0 else {
            let openError = errno
            if waitingErrno != openError {
                waitingErrno = openError
                onStateChange?(.waitingForFile(errno: openError))
            }
            let delay = retryDelay
            retryTask = Task { @MainActor [weak self] in
                try? await Task.sleep(for: delay)
                guard !Task.isCancelled, let self else { return }
                attach(generation: expectedGeneration)
            }
            return
        }

        var eventMask = contentEvents
        if followsReplacement {
            eventMask.formUnion([.delete, .rename, .revoke])
        }
        let newSource = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: eventMask,
            queue: .main
        )
        newSource.setEventHandler { [weak self, weak newSource] in
            guard let self, let newSource,
                isStarted, generation == expectedGeneration,
                source === newSource
            else { return }

            let wasReplaced =
                followsReplacement
                && !newSource.data.isDisjoint(with: [.delete, .rename, .revoke])
            if wasReplaced {
                source = nil
                pendingReplacementDelivery = true
                newSource.cancel()
                attach(generation: expectedGeneration)
            } else {
                onEvent(.contentChanged)
            }
        }
        newSource.setCancelHandler { @Sendable in close(fileDescriptor) }
        newSource.resume()
        source = newSource

        let recoveredFromMissingFile = waitingErrno != nil
        if hasAttached || recoveredFromMissingFile {
            onStateChange?(.recovered)
        } else {
            onStateChange?(.started)
        }
        hasAttached = true
        waitingErrno = nil
        if pendingReplacementDelivery {
            pendingReplacementDelivery = false
            onEvent(.fileReplaced)
        } else if recoveredFromMissingFile {
            onEvent(.fileAvailable)
        }
    }
}
