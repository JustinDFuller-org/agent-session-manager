---
name: swiftui-documentation
description: SwiftUI official doc index — load when building SwiftUI views, modifiers, state management, data flow, AppKit bridging, or any SwiftUI behavior.
allowed-tools: WebFetch(domain:developer.apple.com)
metadata:
  user-invocable: "false"
---

# SwiftUI Documentation Index

Fetch from this index before implementing any SwiftUI feature — do not guess at behavior. One URL per topic — read the most specific one first.

## Discovery

- `https://developer.apple.com/documentation/swiftui` — Main SwiftUI framework page; overview, all topic sections, and sample apps.

## Core App Structure

- `https://developer.apple.com/documentation/swiftui/app-organization` — Entry point and top-level app structure; the `App` protocol and scene composition.
- `https://developer.apple.com/documentation/swiftui/app` — `App` protocol: main entry point for a SwiftUI app (`@main`, `body` returning `some Scene`).
- `https://developer.apple.com/documentation/swiftui/scenes` — Scene types overview: life cycle, platform behavior, and built-in scene types.
- `https://developer.apple.com/documentation/swiftui/scene` — `Scene` protocol: root of a view hierarchy with system-managed life cycle.
- `https://developer.apple.com/documentation/swiftui/scenebuilder` — `SceneBuilder` result builder: composing multiple scenes in an App body.

## App Scenes

- `https://developer.apple.com/documentation/swiftui/windows` — Window scenes: `WindowGroup`, `Window`, window styles, and multi-window behavior.
- `https://developer.apple.com/documentation/swiftui/windowgroup` — `WindowGroup` scene: multi-window support, platform-adaptive behavior.
- `https://developer.apple.com/documentation/swiftui/window` — `Window` scene: single-instance auxiliary windows with an identifier.
- `https://developer.apple.com/documentation/swiftui/settings` — `Settings` scene: macOS Settings window, auto-integrated with the app menu.
- `https://developer.apple.com/documentation/swiftui/customizing-window-styles-and-state-restoration-behavior-in-macos` — macOS window styling: `windowStyle`, `defaultPosition`, state restoration.

## Data & State Management

- `https://developer.apple.com/documentation/swiftui/model-data` — Overview of data flow tools: `@State`, `@Binding`, `@Environment`, and `@Observable`.
- `https://developer.apple.com/documentation/swiftui/state` — `@State` property wrapper: local transient UI state within a view.
- `https://developer.apple.com/documentation/swiftui/binding` — `@Binding` property wrapper: two-way reference to a source of truth owned elsewhere.
- `https://developer.apple.com/documentation/swiftui/environment` — `@Environment` property wrapper: reading observable objects and `EnvironmentValues` from the environment.
- `https://developer.apple.com/documentation/swiftui/environmentvalues` — `EnvironmentValues` collection: all built-in environment keys propagated through a view hierarchy.
- `https://developer.apple.com/documentation/swiftui/bindable` — `@Bindable` property wrapper: creates bindings to `@Observable` model properties in views.
- `https://developer.apple.com/documentation/swiftui/appstorage` — `@AppStorage` property wrapper: reads and writes `UserDefaults`, triggers view updates on change.
- `https://developer.apple.com/documentation/observation/observable` — `@Observable` macro (Observation framework): reactive model objects that SwiftUI tracks for view updates.

## Views — Fundamentals & Layout

- `https://developer.apple.com/documentation/swiftui/view-fundamentals` — Overview of the `View` protocol, view hierarchy, and composition.
- `https://developer.apple.com/documentation/swiftui/view` — `View` protocol: all required and optional modifiers, `body` property, and `@ViewBuilder`.
- `https://developer.apple.com/documentation/swiftui/layout-fundamentals` — Layout overview: stacks, grids, alignment, and spacing.
- `https://developer.apple.com/documentation/swiftui/layout-adjustments` — Fine-tuning layout: alignment, spacing, padding, and layout priority.
- `https://developer.apple.com/documentation/swiftui/view-groupings` — Purpose-driven containers: `Form`, `Group`, `Section`, `GroupBox`, `ControlGroup`, `DisclosureGroup`.
- `https://developer.apple.com/documentation/swiftui/scroll-views` — `ScrollView` and scrolling behavior: axes, content insets, programmatic scrolling.
- `https://developer.apple.com/documentation/swiftui/geometryreader` — `GeometryReader`: reading container size and position for custom layout calculations.
- `https://developer.apple.com/documentation/swiftui/custom-layout` — Custom layout types: `Layout` protocol, `AnyLayout`, animated transitions between layouts.

## Views — Controls & Display

- `https://developer.apple.com/documentation/swiftui/controls-and-indicators` — Controls overview: `Button`, `Toggle`, `Picker`, `Slider`, `Stepper`, `ProgressView`.
- `https://developer.apple.com/documentation/swiftui/text-input-and-output` — Text display and input: `Text`, `TextField`, `TextEditor`, `SecureField`, formatting.
- `https://developer.apple.com/documentation/swiftui/images` — `Image` and SF Symbols: system images, custom assets, resizable, rendering mode.
- `https://developer.apple.com/documentation/swiftui/shapes` — Built-in shapes: `Circle`, `Rectangle`, `RoundedRectangle`, `Capsule`, `Ellipse`, `Path`.
- `https://developer.apple.com/documentation/swiftui/view-configuration` — Configuring views: `.disabled`, `.hidden`, `.tag`, `.id`, `.zIndex`, `.labelsHidden`.

## Presentation & Navigation

- `https://developer.apple.com/documentation/swiftui/modal-presentations` — Modal presentation: `.sheet`, `.alert`, `.confirmationDialog`, `.popover`, `.inspector`.
- `https://developer.apple.com/documentation/swiftui/navigation` — Navigation overview: `NavigationStack`, `NavigationSplitView`, `TabView`.
- `https://developer.apple.com/documentation/swiftui/navigationstack` — `NavigationStack`: push/pop stack, navigation path, programmatic navigation.
- `https://developer.apple.com/documentation/swiftui/tabview` — `TabView`: tab bar with `.tabItem`, selection binding, `.tabViewStyle`.

## Menus, Commands & Toolbars

- `https://developer.apple.com/documentation/swiftui/menus-and-commands` — Menus and commands overview: menu bar, context menus, `commands(content:)`.
- `https://developer.apple.com/documentation/swiftui/menu` — `Menu` control: hierarchical menus, `Menu` nesting, `Divider` separators.
- `https://developer.apple.com/documentation/swiftui/building-and-customizing-the-menu-bar-with-swiftui` — macOS menu bar: building native menus with SwiftUI for iPadOS and macOS.
- `https://developer.apple.com/documentation/swiftui/toolbars` — Toolbar overview: `ToolbarItem`, `ToolbarItemGroup`, `.toolbar` modifier, placement.

## Event Handling

- `https://developer.apple.com/documentation/swiftui/gestures` — Gesture overview: `TapGesture`, `DragGesture`, `LongPressGesture`, simultaneous and sequenced gestures.
- `https://developer.apple.com/documentation/swiftui/input-events` — Hardware input: keyboard events, key equivalents, `KeyboardShortcut`, `onKeyPress`.
- `https://developer.apple.com/documentation/swiftui/focus` — Focus management: `@FocusState`, `.focused`, `.focusScope`, `.focusedValue`, `FocusedValues`.
- `https://developer.apple.com/documentation/swiftui/system-events` — System event callbacks: `onOpenURL`, `onContinueUserActivity`, `onNotification`, scene phase.
- `https://developer.apple.com/documentation/swiftui/drag-and-drop` — Drag and drop: `.draggable`, `.dropDestination`, drag previews, `Transferable`.

## AppKit Integration

- `https://developer.apple.com/documentation/swiftui/appkit-integration` — AppKit bridging overview: hosting SwiftUI in AppKit, AppKit views in SwiftUI.
- `https://developer.apple.com/documentation/swiftui/nsviewrepresentable` — `NSViewRepresentable` protocol: wrapping AppKit views for use in SwiftUI hierarchies.
- `https://developer.apple.com/documentation/swiftui/nshostingcontroller` — `NSHostingController`: AppKit view controller that hosts a SwiftUI view hierarchy.
- `https://developer.apple.com/documentation/swiftui/nshostingview` — `NSHostingView`: AppKit view that hosts a SwiftUI view hierarchy (without a controller).

## Styling & Animation

- `https://developer.apple.com/documentation/swiftui/view-styles` — View styles: `.buttonStyle`, `.toggleStyle`, `.pickerStyle`, `.textFieldStyle`, `.labelStyle`, `.menuStyle`, `.progressViewStyle`.
- `https://developer.apple.com/documentation/swiftui/animations` — Animation overview: implicit and explicit animations, `withAnimation`, `Animation` type, timing curves.
- `https://developer.apple.com/documentation/swiftui/animation` — `Animation` type: `.easeInOut`, `.spring`, `.linear`, `repeatForever`, `speed`.

## Tool Support

- `https://developer.apple.com/documentation/swiftui/previews-in-xcode` — Xcode previews: `#Preview` macro, `PreviewProvider`, preview traits, variants.
- `https://developer.apple.com/documentation/swiftui/performance-analysis` — Performance: identifying slow updates, `Self._printChanges`, view identity and lifetime.

## Accessibility

- `https://developer.apple.com/documentation/swiftui/accessibility-fundamentals` — Accessibility: `.accessibilityLabel`, `.accessibilityIdentifier`, `.accessibilityHint`, `.help`, `.disabled`, dynamic type.
