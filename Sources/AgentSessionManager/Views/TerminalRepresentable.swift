import SwiftUI
import SwiftTerm

struct TerminalRepresentable: NSViewRepresentable {
    let controller: TerminalController

    func makeNSView(context: Context) -> LocalProcessTerminalView {
        controller.terminalView
    }

    func updateNSView(_ nsView: LocalProcessTerminalView, context: Context) {
        context.coordinator.startIfNeeded(view: nsView, controller: controller)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    @MainActor
    final class Coordinator {
        private var started = false

        func startIfNeeded(view: LocalProcessTerminalView, controller: TerminalController) {
            guard !started else { return }
            guard view.frame.width > 0, view.frame.height > 0 else {
                DispatchQueue.main.async { [weak self] in
                    self?.startIfNeeded(view: view, controller: controller)
                }
                return
            }
            started = true
            controller.startProcess()
        }
    }
}
