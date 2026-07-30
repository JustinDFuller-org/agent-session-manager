import SwiftTerm
import SwiftUI

struct TerminalScrollbackTelemetry {
    let limit: ScrollbackLimit
    let source: String
    let paneID: String
    let paneName: String
    let tabID: String
    let tabName: String

    var attributes: [String: String] {
        [
            "pane.id": paneID,
            "pane.name": paneName,
            "tab.id": tabID,
            "tab.name": tabName,
            "scrollback.mode": limit.modeName,
            "scrollback.lines": String(limit.resolvedLines),
            "scrollback.source": source,
            "result": "applied",
        ]
    }
}

struct TerminalRepresentable: NSViewRepresentable {
    let controller: TerminalController
    let isActive: Bool
    let scrollbackLimit: ScrollbackLimit
    let scrollbackSource: String
    let paneID: String
    let paneName: String
    let tabID: String
    let tabName: String

    func makeNSView(context: Context) -> LocalProcessTerminalView {
        controller.terminalView
    }

    func updateNSView(_ nsView: LocalProcessTerminalView, context: Context) {
        context.coordinator.startIfNeeded(view: nsView, controller: controller)
        context.coordinator.focusIfNeeded(view: nsView, isActive: isActive)
        let resolvedLines = scrollbackLimit.resolvedLines
        if context.coordinator.lastAppliedScrollbackLines != resolvedLines {
            nsView.changeScrollback(resolvedLines)
            context.coordinator.lastAppliedScrollbackLines = resolvedLines
            TracingService.shared.record(
                "terminal.scrollback.changed",
                attributes: TerminalScrollbackTelemetry(
                    limit: scrollbackLimit,
                    source: scrollbackSource,
                    paneID: paneID,
                    paneName: paneName,
                    tabID: tabID,
                    tabName: tabName
                ).attributes
            )
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    @MainActor
    final class Coordinator {
        private var started = false
        private var wasActive = false
        fileprivate var lastAppliedScrollbackLines: Int?

        func startIfNeeded(view: LocalProcessTerminalView, controller: TerminalController) {
            guard !started else { return }
            guard view.frame.width > 0, view.frame.height > 0 else {
                DispatchQueue.main.async { [weak self] in
                    self?.startIfNeeded(view: view, controller: controller)
                }
                return
            }
            // SwiftUI's GeometryReader/LazyVGrid can produce multiple layout passes
            // with intermediate (tiny but non-zero) frames. Wait until the frame is
            // stable across two consecutive run-loop iterations before opening the PTY,
            // so terminal.cols/rows reflect the final layout dimensions.
            started = true
            waitForStableFrame(view: view, controller: controller, lastSize: view.frame.size, attempt: 0)
        }

        private func waitForStableFrame(
            view: LocalProcessTerminalView,
            controller: TerminalController,
            lastSize: CGSize,
            attempt: Int
        ) {
            DispatchQueue.main.async { [weak self, weak view, weak controller] in
                guard let view, let controller else { return }
                let currentSize = view.frame.size
                if currentSize == lastSize || attempt >= 10 {
                    controller.startProcess()
                } else {
                    self?.waitForStableFrame(
                        view: view, controller: controller, lastSize: currentSize, attempt: attempt + 1)
                }
            }
        }

        func focusIfNeeded(view: LocalProcessTerminalView, isActive: Bool) {
            defer { wasActive = isActive }
            guard isActive && !wasActive else { return }
            focusWhenReady(view: view)
        }

        func focusWhenReady(view: LocalProcessTerminalView, attempt: Int = 0) {
            let ready = view.window != nil && view.frame.width > 0 && view.frame.height > 0
            if ready {
                view.window?.makeFirstResponder(view)
                if view.window?.firstResponder === view { return }
            }
            guard attempt < 10 else { return }
            DispatchQueue.main.async { [weak self, weak view] in
                guard let view else { return }
                self?.focusWhenReady(view: view, attempt: attempt + 1)
            }
        }
    }
}
