import SwiftUI

struct ScrollbackLimitEditor: View {
    let value: ScrollbackLimit?
    let allowsInheritance: Bool
    let inheritedValue: ScrollbackLimit
    let accessibilityPrefix: String
    let onChange: (ScrollbackLimit?) -> Void
    @Binding var finiteLinesText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker(
                "Scrollback",
                selection: Binding(
                    get: {
                        if value == nil { return "inherit" }
                        if case .unlimited? = value { return "unlimited" }
                        return "finite"
                    },
                    set: { mode in
                        switch mode {
                        case "inherit":
                            onChange(nil)
                        case "unlimited":
                            onChange(.unlimited)
                        default:
                            if case .finite? = value {
                                return
                            }
                            onChange(.finite(inheritedValue.resolvedLines))
                        }
                    }
                )
            ) {
                if allowsInheritance {
                    Text("Use Global Default (\(inheritedValue.resolvedLines.formatted()) lines)")
                        .tag("inherit")
                }
                Text("Custom Limit").tag("finite")
                Text("Unlimited (50,000-line cap)").tag("unlimited")
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .accessibilityIdentifier("\(accessibilityPrefix)-mode-picker")

            if case .finite(let lines)? = value {
                HStack(spacing: 8) {
                    TextField(
                        "Lines",
                        text: $finiteLinesText
                    )
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                    .frame(width: 140)
                    .accessibilityIdentifier("\(accessibilityPrefix)-lines-field")
                    .onAppear {
                        finiteLinesText = String(lines)
                    }
                    .onSubmit {
                        guard let parsed = Int(finiteLinesText) else {
                            finiteLinesText = String(lines)
                            return
                        }
                        let normalized = ScrollbackLimit(finiteLines: parsed)
                        finiteLinesText = String(normalized.resolvedLines)
                        onChange(normalized)
                    }

                    Button("Apply Limit") {
                        guard let parsed = Int(finiteLinesText) else {
                            finiteLinesText = String(lines)
                            return
                        }
                        let normalized = ScrollbackLimit(finiteLines: parsed)
                        finiteLinesText = String(normalized.resolvedLines)
                        onChange(normalized)
                    }
                    .accessibilityIdentifier("\(accessibilityPrefix)-apply-button")
                }
            }

            if value == nil {
                Text("This pane follows the global scrollback setting.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if value == .unlimited {
                Text("Keeps up to 50,000 lines per pane to prevent unbounded memory use.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text(
                    "Choose \(ScrollbackLimit.minimumLines.formatted())–\(ScrollbackLimit.maximumFiniteLines.formatted()) lines."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .onChange(of: value) { _, newValue in
            guard case .finite(let lines)? = newValue else { return }
            finiteLinesText = String(lines)
        }
    }
}
