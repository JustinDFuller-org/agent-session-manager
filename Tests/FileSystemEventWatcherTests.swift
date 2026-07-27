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
            case .contentChanged:
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
        let delivered = expectation(description: "write delivered")
        let watcher = FileSystemEventWatcher(
            url: file,
            followsReplacement: true,
            retryDelay: .milliseconds(20),
            onEvent: { _ in delivered.fulfill() },
            onStateChange: { state in
                if case .recovered = state {
                    started.fulfill()
                }
            }
        )

        watcher.start()
        try Data().write(to: file)
        await fulfillment(of: [started], timeout: 2)
        try Data("updated".utf8).write(to: file)
        await fulfillment(of: [delivered], timeout: 2)
        watcher.cancel()
    }

    func testCancelSuppressesQueuedDeliveryAndRetry() async throws {
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
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.appending(path: "missing.json").path))
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
