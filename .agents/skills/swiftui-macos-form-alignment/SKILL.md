---
name: swiftui-macos-form-alignment
description: "SwiftUI macOS Form layout: alignment override bug, background control, and VStack-based alternative. Load when debugging alignment issues inside Form rows, or when row controls (toggles, text fields, pickers) are visually misaligned with their labels on macOS."
---

# SwiftUI macOS Form Alignment

## The Problem

`Form { }.formStyle(.grouped)` on macOS renders using NSTableView internally. Each direct child of a `Section` is wrapped in a **fixed-height table row cell** that **center-aligns its content vertically**, regardless of any alignment modifiers you put on the view inside the row.

This means:

```swift
// ❌ Does NOT work — HStack(alignment: .top) is ignored by the Form row container
Section {
    HStack(alignment: .top) {
        VStack { Text(label); Text(description) }  // tall due to description
        Spacer()
        TextField(...)  // shorter — ends up centered, visually below label
    }
}
```

No matter what alignment you apply to the HStack (`.top`, `.firstTextBaseline`), or whether you use `.overlay(alignment: .topTrailing)`, the Form's row container wins and centers the whole thing.

## Diagnosing Alignment Issues

Add background colors to every subview to see actual frame extents at runtime:

```swift
Text(label).background(Color.red.opacity(0.4))
TextField(...).background(Color.blue.opacity(0.4))
HStack { ... }.background(Color.green.opacity(0.4))
```

If the colored boxes show the layout you want but the controls still appear in the wrong place, the Form container is the culprit — not your alignment modifiers.

## Fix 1: Restructure to put label and control on the same line

Put the control **on the same line as the label** (not as a sibling of a tall VStack), and move the description to its own line below. With both items in the same `HStack`, there is no height mismatch and center alignment looks correct:

```swift
// ✓ Label and control in the same HStack — always at the same height
VStack(alignment: .leading, spacing: 4) {
    HStack(alignment: .top) {
        Text(label).font(...)
        Spacer()
        HStack(alignment: .center, spacing: 4) {
            Text(modifier)
            TextField(...)
        }
    }
    Text(description).font(.caption).foregroundStyle(.secondary)
}
.padding(.vertical, 8)
```

## Fix 2: Replace Form with ScrollView + VStack (most reliable)

When Fix 1 is insufficient (e.g. complex multi-row alignment), ditch `Form` entirely and use a plain `ScrollView + VStack`. Style the sections manually to match the grouped form appearance:

```swift
ScrollView {
    VStack(alignment: .leading, spacing: 20) {
        // Section
        VStack(alignment: .leading, spacing: 6) {
            Text("Section Header")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.leading, 4)
            VStack(spacing: 0) {
                MyRow(...)
                Divider().padding(.leading, 16)
                MyRow(...)
            }
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
    .padding(20)
}
```

Each `MyRow` owns its own horizontal padding (`.padding(.horizontal, 16)`) since Form no longer provides it.

Without `Form`, alignment modifiers work exactly as documented. `HStack(alignment: .top)` top-aligns all children. No surprises.

## Form Background Control

`Form { }.formStyle(.grouped)` fills the content area with its own background color, which differs from `NSColor.windowBackgroundColor`. To unify backgrounds across pages that mix Form and non-Form layouts:

```swift
ScrollView {
    Form { ... }
    .formStyle(.grouped)
    .scrollContentBackground(.hidden)  // hides Form's internal scroll background
}
.background(Color(NSColor.windowBackgroundColor))  // shows window background in the gap areas
```

`.scrollContentBackground(.hidden)` requires macOS 13+. It hides the scrollable view's background but leaves section cell backgrounds intact — sections appear as lighter cards on the darker window background.

## When to Use Form vs VStack

| Situation | Use |
|-----------|-----|
| Simple toggle/checkbox rows | `Form` — center alignment looks fine when label ≈ control height |
| Picker or segmented control rows | `Form` — controls are tall enough that centering is acceptable |
| TextField rows where label top must align with field top | `VStack + ScrollView` |
| Any row needing `.top` or `.firstTextBaseline` alignment | `VStack + ScrollView` |
| Rows with multi-line descriptions AND right-side controls | `VStack + ScrollView` |
