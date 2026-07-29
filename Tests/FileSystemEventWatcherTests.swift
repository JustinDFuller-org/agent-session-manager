import XCTest

@testable import AgentSessionManager

@MainActor
final class FileSystemEventWatcherTests: XCTestCase {
    private var directory: URL!

    override func setUp() async throws {
        try await super.setUp()
        directory = FileManager.default.temporaryDirectory
            .appending(path: "file-system-watcher-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        if let directory {
            try? FileManager.default.removeItem(at: directory)
        }
        try await super.tearDown()
    }

    func testWriteDeliversOnMainActor() async throws {
        let file = directory.appending(path: "watched.json")
        try Data().write(to: file)
        let delivered = expectation(description: "write delivered")
        let watcher = FileSystemEventWatcher(url: file, followsReplacement: false) { event in
            MainActor.assertIsolated()
            if case .contentChanged = event {
                delivered.fulfill()
            }
        }

        watcher.start()
        try Data("updated".utf8).write(to: file)

        await fulfillment(of: [delivered], timeout: 2)
        watcher.cancel()
    }

    func testAtomicReplacementReattachesToNewInode() async throws {
        let file = directory.appending(path: "replaced.json")
        try Data().write(to: file)
        let replacementDelivered = expectation(description: "replacement delivered")
        let laterWriteDelivered = expectation(description: "write on replacement delivered")
        var sawReplacement = false
        let watcher = FileSystemEventWatcher(url: file, followsReplacement: true) { event in
            switch event {
            case .fileReplaced:
                sawReplacement = true
                replacementDelivered.fulfill()
            case .contentChanged where sawReplacement:
                laterWriteDelivered.fulfill()
            case .contentChanged, .fileAvailable:
                break
            }
        }

        watcher.start()
        try Data("replacement".utf8).write(to: file, options: .atomic)
        await fulfillment(of: [replacementDelivered], timeout: 2)
        try Data("later".utf8).write(to: file)
        await fulfillment(of: [laterWriteDelivered], timeout: 2)
        watcher.cancel()
    }

    func testStartsWhenMissingFileAppears() async throws {
        let file = directory.appending(path: "created-later.json")
        let started = expectation(description: "watcher recovered")
        let available = expectation(description: "created file delivered")
        let laterWrite = expectation(description: "later write delivered")
        let watcher = FileSystemEventWatcher(
            url: file,
            followsReplacement: true,
            retryDelay: .milliseconds(20),
            onEvent: { event in
                if event == .fileAvailable {
                    available.fulfill()
                } else if event == .contentChanged {
                    laterWrite.fulfill()
                }
            },
            onStateChange: { state in
                if case .recovered = state {
                    started.fulfill()
                }
            }
        )

        watcher.start()
        try Data("initial".utf8).write(to: file)
        await fulfillment(of: [started, available], timeout: 2)
        try Data("updated".utf8).write(to: file)
        await fulfillment(of: [laterWrite], timeout: 2)
        watcher.cancel()
    }

    func testCancelSuppressesQueuedDelivery() async throws {
        let file = directory.appending(path: "cancelled.json")
        try Data().write(to: file)
        let delivery = expectation(description: "no delivery after cancel")
        delivery.isInverted = true
        let watcher = FileSystemEventWatcher(url: file, followsReplacement: true) { _ in
            delivery.fulfill()
        }

        watcher.start()
        try Data("queued".utf8).write(to: file)
        watcher.cancel()

        await fulfillment(of: [delivery], timeout: 0.2)
    }

    func testCancelSuppressesMissingFileRetry() async throws {
        let file = directory.appending(path: "cancelled-retry.json")
        let delivery = expectation(description: "no delivery after retry cancellation")
        delivery.isInverted = true
        let watcher = FileSystemEventWatcher(
            url: file,
            followsReplacement: true,
            retryDelay: .milliseconds(20)
        ) { _ in
            delivery.fulfill()
        }

        watcher.start()
        watcher.cancel()
        try Data().write(to: file)

        await fulfillment(of: [delivery], timeout: 0.2)
    }

    func testMissingFileRetryDoesNotRetainDiscardedWatcher() async {
        let file = directory.appending(path: "discarded-retry.json")
        weak var discardedWatcher: FileSystemEventWatcher?
        var watcher: FileSystemEventWatcher? = FileSystemEventWatcher(
            url: file,
            followsReplacement: true,
            retryDelay: .milliseconds(100)
        ) { _ in }
        watcher?.start()
        discardedWatcher = watcher
        try? await Task.sleep(for: .milliseconds(20))
        watcher = nil

        XCTAssertNil(discardedWatcher)
    }

    func testRepeatedStartAndCancelAreIdempotent() async {
        let file = directory.appending(path: "cycles.json")
        try? Data().write(to: file)
        let watcher = FileSystemEventWatcher(url: file, followsReplacement: true) { _ in }

        for _ in 0..<100 {
            watcher.start()
            watcher.start()
            watcher.cancel()
            watcher.cancel()
        }

        try? await Task.sleep(for: .milliseconds(100))
    }
}
