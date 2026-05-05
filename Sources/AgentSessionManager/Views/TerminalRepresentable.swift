import SwiftUI
import SwiftTerm

struct TerminalRepresentable: NSViewRepresentable {
    let controller: TerminalController
    let isActive: Bool

    func makeNSView(context: Context) -> LocalProcessTerminalView {
        controller.terminalView
    }

    func updateNSView(_ nsView: LocalProcessTerminalView, context: Context) {
        context.coordinator.startIfNeeded(view: nsView, controller: controller)
        context.coordinator.focusIfNeeded(view: nsView, isActive: isActive)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    @MainActor
    final class Coordinator {
        private var started = false
        private var wasActive = false

        func startIfNeeded(view: LocalProcessTerminalView, controller: TerminalController) {
            guard !started else { return }
            guard view.frame.width > 0, view.frame.height > 0 else {
                DispatchQueue.main.async { [weak self] in
                    self?.startIfNeeded(view: view, controller: controller)
                }
                return
            }
            // Defer to the next run loop so that any in-flight AppKit setFrameSize
            // calls have updated terminal.cols/rows before the PTY is sized.
            started = true
            DispatchQueue.main.async { [weak controller] in
                controller?.startProcess()
            }
        }

        func focusIfNeeded(view: LocalProcessTerminalView, isActive: Bool) {
            defer { wasActive = isActive }
            guard isActive && !wasActive else { return }
            view.window?.makeFirstResponder(view)
        }
    }
}
