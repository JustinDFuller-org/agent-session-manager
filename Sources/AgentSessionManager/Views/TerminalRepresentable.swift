import SwiftUI
import SwiftTerm

struct TerminalRepresentable: NSViewRepresentable {
    let controller: TerminalController

    func makeNSView(context: Context) -> LocalProcessTerminalView {
        controller.terminalView
    }

    func updateNSView(_ nsView: LocalProcessTerminalView, context: Context) {}
}
