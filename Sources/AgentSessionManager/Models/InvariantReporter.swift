import Foundation

extension Notification.Name {
    static let invariantReporterDidChange = Notification.Name("invariantReporterDidChange")
}

final class InvariantReporter: @unchecked Sendable {
    static let shared = InvariantReporter()

    private let lock = NSLock()
    private var writer: InvariantLogWriter?
    private var _latestWriterError: String?
    private var testCaptureEnabled = false
    private var _violationsForTesting: [InvariantViolation] = []

    private init() {}

    var latestWriterError: String? {
        lock.withLock { _latestWriterError }
    }

    var violationsForTesting: [InvariantViolation] {
        lock.withLock { _violationsForTesting }
    }

    @MainActor
    func configure(from settings: AppSettings) {
        lock.withLock {
            writer =
                settings.debugModeEnabled
                ? InvariantLogWriter(
                    directory: settings.resolvedInvariantDirectoryURL,
                    maxBytes: AppSettings.debugFileMaxBytes
                )
                : nil
            _latestWriterError = nil
        }
        notifyChange()
    }

    @discardableResult
    func check(_ invariant: Invariant, _ condition: @autoclosure () -> Bool, context: [String: String] = [:]) -> Bool {
        let passed = condition()
        if !passed { violated(invariant, context: context) }
        return passed
    }

    func violated(_ invariant: Invariant, context: [String: String] = [:]) {
        let violation = InvariantViolation(invariant: invariant, context: context)
        let reserved = [
            "invariant.id": invariant.id,
            "invariant.integration": invariant.integration,
            "invariant.severity": invariant.severity.rawValue,
            "invariant.occurrence_id": violation.id.uuidString,
        ]
        let traceAttributes = context.merging(reserved) { _, reservedValue in reservedValue }
        TracingService.shared.record(invariant.traceEventName ?? "invariant.violated", attributes: traceAttributes)

        let (writer, captureEnabled) = lock.withLock { (self.writer, testCaptureEnabled) }
        if captureEnabled {
            lock.withLock { _violationsForTesting.append(violation) }
        }
        guard let writer else {
            notifyChange()
            return
        }
        do {
            try writer.append(violation)
            lock.withLock { _latestWriterError = nil }
        } catch {
            lock.withLock { _latestWriterError = error.localizedDescription }
            TracingService.shared.record(
                "invariant.log.write_failed",
                attributes: ["error": error.localizedDescription]
            )
        }
        notifyChange()
    }

    func enableTestCapture() {
        lock.withLock { testCaptureEnabled = true }
    }

    func resetForTesting() {
        lock.withLock {
            writer = nil
            _latestWriterError = nil
            testCaptureEnabled = false
            _violationsForTesting = []
        }
    }

    func setWriterForTesting(_ writer: InvariantLogWriter?) {
        lock.withLock { self.writer = writer }
    }

    private func notifyChange() {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .invariantReporterDidChange, object: nil)
        }
    }
}
