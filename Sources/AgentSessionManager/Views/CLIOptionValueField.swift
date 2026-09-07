import SwiftUI

struct CLIOptionValueField: View {
    let option: CLIOptionConfig
    @Binding var value: String
    @Binding var values: [String]
    let enabled: Bool

    @State private var isEditingCustom = false
    @State private var customDraft = ""

    var body: some View {
        Group {
            if case .string(let placeholder) = option.optionType {
                if option.presetValues.isEmpty {
                    TextField(placeholder, text: $value)
                        .textFieldStyle(.roundedBorder)
                        .disabled(!enabled)
                        .accessibilityIdentifier("cli-option-value-field-\(option.id)")
                } else if option.allowsMultipleValues {
                    VStack(alignment: .leading, spacing: 4) {
                        multiSelectMenu
                        if isEditingCustom {
                            TextField(placeholder, text: $customDraft)
                                .textFieldStyle(.roundedBorder)
                                .disabled(!enabled)
                                .onSubmit(addCustomDraft)
                                .accessibilityIdentifier("cli-option-value-custom-field-\(option.id)")
                        }
                    }
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        singleSelectMenu(placeholder: placeholder)
                        if isEditingCustom {
                            TextField(placeholder, text: $value)
                                .textFieldStyle(.roundedBorder)
                                .disabled(!enabled)
                                .accessibilityIdentifier("cli-option-value-custom-field-\(option.id)")
                        }
                    }
                }
            } else {
                Color.clear
            }
        }
    }

    private var multiSelectSummary: String {
        switch values.count {
        case 0: return "Select…"
        case 1: return values[0]
        default: return "\(values.count) selected"
        }
    }

    @ViewBuilder
    private var multiSelectMenu: some View {
        Menu {
            ForEach(option.presetValues, id: \.self) { preset in
                Toggle(preset, isOn: multiSelectBinding(for: preset))
            }
            Divider()
            Button("Add custom…") { isEditingCustom = true }
        } label: {
            Text(multiSelectSummary).lineLimit(1)
        }
        .disabled(!enabled)
        .accessibilityIdentifier("cli-option-value-menu-\(option.id)")
    }

    private func multiSelectBinding(for preset: String) -> Binding<Bool> {
        Binding(
            get: { values.contains(preset) },
            set: { isOn in
                if isOn {
                    if !values.contains(preset) { values.append(preset) }
                } else {
                    values.removeAll { $0 == preset }
                }
            }
        )
    }

    @ViewBuilder
    private func singleSelectMenu(placeholder: String) -> some View {
        Menu {
            ForEach(option.presetValues, id: \.self) { preset in
                Button {
                    value = preset
                    isEditingCustom = false
                } label: {
                    if value == preset {
                        Label(preset, systemImage: "checkmark")
                    } else {
                        Text(preset)
                    }
                }
            }
            Divider()
            Button("Custom…") { isEditingCustom = true }
        } label: {
            Text(value.isEmpty ? placeholder : value).lineLimit(1)
        }
        .disabled(!enabled)
        .accessibilityIdentifier("cli-option-value-menu-\(option.id)")
    }

    private func addCustomDraft() {
        let trimmed = customDraft.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !values.contains(trimmed) else { return }
        values.append(trimmed)
        customDraft = ""
    }
}
