---
name: appkit-documentation
description: AppKit official doc index — load when building AppKit features, NSView, NSWindow, NSEvent, NSColor, NSWorkspace, or any AppKit behavior.
allowed-tools: WebFetch(domain:developer.apple.com)
metadata:
  user-invocable: "false"
---

# AppKit Documentation Index

Fetch from this index before implementing any AppKit feature — do not guess at behavior. One URL per topic — read the most specific one first.

## Discovery

- `https://developer.apple.com/documentation/appkit` — Main AppKit framework page; overview, all topic sections, and current availability.

## App Structure & Lifecycle

- `https://developer.apple.com/documentation/appkit/app-and-environment` — App lifecycle section: NSApplication, NSRunningApplication, NSWorkspace, delegation.
- `https://developer.apple.com/documentation/appkit/nsapplication` — NSApplication: manages main event loop and shared app resources.
- `https://developer.apple.com/documentation/appkit/nsapplicationdelegate` — NSApplicationDelegate: app lifecycle and system service callbacks.
- `https://developer.apple.com/documentation/appkit/nsworkspace` — NSWorkspace: launch apps, file-handling services, open URLs.
- `https://developer.apple.com/documentation/appkit/nsrunningapplication` — NSRunningApplication: query and control running app instances.

## Windows & Panels

- `https://developer.apple.com/documentation/appkit/windows-panels-and-screens` — Windows, panels, screens, alerts, panels overview.
- `https://developer.apple.com/documentation/appkit/nswindow` — NSWindow: window creation, style masks, key/main status, ordering.
- `https://developer.apple.com/documentation/appkit/nswindowdelegate` — NSWindowDelegate: window lifecycle callbacks (close, resize, key status).
- `https://developer.apple.com/documentation/appkit/nspanel` — NSPanel: auxiliary panels distinct from main windows.
- `https://developer.apple.com/documentation/appkit/nsscreen` — NSScreen: monitor and screen attributes.
- `https://developer.apple.com/documentation/appkit/nsalert` — NSAlert: modal dialogs and window-modal sheets.
- `https://developer.apple.com/documentation/appkit/nsopenpanel` — NSOpenPanel: file/folder open dialog.
- `https://developer.apple.com/documentation/appkit/nssavepanel` — NSSavePanel: file save dialog.
- `https://developer.apple.com/documentation/appkit/nspopover` — NSPopover: transient content displayed relative to existing content.
- `https://developer.apple.com/documentation/appkit/nswindowtab` — NSWindowTab: tab within a tabbed window group.
- `https://developer.apple.com/documentation/appkit/nswindowtabgroup` — NSWindowTabGroup: collection of tabbed windows.
- `https://developer.apple.com/documentation/appkit/restoring-your-app-s-state-with-appkit` — Window restoration: preserving app state across launches.

## Views & Controls

- `https://developer.apple.com/documentation/appkit/views-and-controls` — Views and controls overview: NSView, NSControl, container views.
- `https://developer.apple.com/documentation/appkit/nsview` — NSView: view hierarchy, drawing, printing, event handling fundamentals.
- `https://developer.apple.com/documentation/appkit/nscontrol` — NSControl: base class for interactive controls with target-action pattern.
- `https://developer.apple.com/documentation/appkit/nsresponder` — NSResponder: abstract base for event and command processing, responder chain.
- `https://developer.apple.com/documentation/appkit/nsbutton` — NSButton: clickable action triggers.
- `https://developer.apple.com/documentation/appkit/nstextfield` — NSTextField: text display and editing control.
- `https://developer.apple.com/documentation/appkit/nsimageview` — NSImageView: image display in views.
- `https://developer.apple.com/documentation/appkit/nsprogressindicator` — NSProgressIndicator: task progress visual feedback.
- `https://developer.apple.com/documentation/appkit/nsswitch` — NSSwitch: binary on/off toggle control.
- `https://developer.apple.com/documentation/appkit/nssegmentedcontrol` — NSSegmentedControl: horizontal group of buttons.
- `https://developer.apple.com/documentation/appkit/nsvisualeffectview` — NSVisualEffectView: translucency and vibrancy effects.
- `https://developer.apple.com/documentation/appkit/nscombobutton` — NSComboButton: button with a pull-down menu and default action.
- `https://developer.apple.com/documentation/appkit/nspopupbutton` — NSPopUpButton: item-from-list selection control.
- `https://developer.apple.com/documentation/appkit/nscell` — NSCell: lightweight text/image display in views.
- `https://developer.apple.com/documentation/appkit/scroll-view` — NSScrollView: scrollable content container.
- `https://developer.apple.com/documentation/appkit/nssplitview` — NSSplitView: resizable split-panel view.
- `https://developer.apple.com/documentation/appkit/nsstackview` — NSStackView: horizontal/vertical stack of views with auto layout.
- `https://developer.apple.com/documentation/appkit/toolbar` — NSToolbar: controls below the window title bar.
- `https://developer.apple.com/documentation/appkit/table-view` — NSTableView: rows and columns of data.
- `https://developer.apple.com/documentation/appkit/outline-view` — NSOutlineView: hierarchical expandable data.
- `https://developer.apple.com/documentation/appkit/collection-view` — NSCollectionView: configurable item arrangement.
- `https://developer.apple.com/documentation/appkit/slider` — NSSlider: value selection from a range.
- `https://developer.apple.com/documentation/appkit/nsstepper` — NSStepper: up/down arrow increment/decrement control.
- `https://developer.apple.com/documentation/appkit/search-field` — NSSearchField: text-based search interface.
- `https://developer.apple.com/documentation/appkit/nsbox` — NSBox: stylized rectangular container with optional title.

## View Controllers

- `https://developer.apple.com/documentation/appkit/view-management` — View controller architecture: NSViewController, NSWindowController.
- `https://developer.apple.com/documentation/appkit/nsviewcontroller` — NSViewController: view lifecycle management and presentation.
- `https://developer.apple.com/documentation/appkit/nswindowcontroller` — NSWindowController: window life cycle management from nib or programmatically.
- `https://developer.apple.com/documentation/appkit/nssplitviewcontroller` — NSSplitViewController: managed adjacent views with dividers.
- `https://developer.apple.com/documentation/appkit/nstabviewcontroller` — NSTabViewController: tab-based content switching.
- `https://developer.apple.com/documentation/appkit/nspagecontroller` — NSPageController: swipe navigation between views.

## Event Handling

- `https://developer.apple.com/documentation/appkit/mouse-keyboard-and-trackpad` — Mouse, keyboard, trackpad events: NSEvent and responder chain.
- `https://developer.apple.com/documentation/appkit/nsevent` — NSEvent: event object with type, location, timestamp, key code, modifier flags.
- `https://developer.apple.com/documentation/appkit/nsevent/modifierflags-swift.struct` — NSEvent.ModifierFlags: shift, command, control, option, function key states.
- `https://developer.apple.com/documentation/appkit/nsevent/eventtypemask` — NSEvent.EventTypeMask: event type filtering for addLocalMonitorForEvents.
- `https://developer.apple.com/documentation/appkit/nsevent/phase-swift.struct` — NSEvent.Phase: scroll/touch event phase constants.
- `https://developer.apple.com/documentation/appkit/nstouch` — NSTouch: touch event snapshot.
- `https://developer.apple.com/documentation/appkit/nscursor` — NSCursor: pointer management, push/pop, custom cursors.
- `https://developer.apple.com/documentation/appkit/nstrackingarea` — NSTrackingArea: mouse-tracking and cursor-update region in a view.

## Keyboard Monitoring & Shortcuts

- `https://developer.apple.com/documentation/appkit/nsevent/eventtypemask/keydown` — NSEvent.EventTypeMask.keyDown filter detail.
- `https://developer.apple.com/documentation/appkit/nsevent/1534530-modifierflags` — NSEvent.modifierFlags property: inspecting modifier state.
- `https://developer.apple.com/documentation/appkit/nsevent/1528905-characters` — NSEvent.characters property: character string of a key event.
- `https://developer.apple.com/documentation/appkit/nsevent/1528906-charactersignoringmodifiers` — NSEvent.charactersIgnoringModifiers: characters without modifier effect.

## Menus & Status Bar

- `https://developer.apple.com/documentation/appkit/menus-cursors-and-the-dock` — Menus, cursors, Dock overview.
- `https://developer.apple.com/documentation/appkit/nsmenu` — NSMenu: app menu bar and contextual menus.
- `https://developer.apple.com/documentation/appkit/nsmenuitem` — NSMenuItem: individual command item in a menu, key equivalent, action.
- `https://developer.apple.com/documentation/appkit/nsmenudelegate` — NSMenuDelegate: menu display and event callbacks.
- `https://developer.apple.com/documentation/appkit/nsstatusbar` — NSStatusBar: system menu bar item collection.
- `https://developer.apple.com/documentation/appkit/nsstatusitem` — NSStatusItem: individual menu bar element.
- `https://developer.apple.com/documentation/appkit/nsstatusbarbutton` — NSStatusBarButton: appearance and behavior of a menu bar item.
- `https://developer.apple.com/documentation/appkit/nsdocktile` — NSDockTile: Dock icon customization and badge.

## Gestures

- `https://developer.apple.com/documentation/appkit/gestures` — Gesture recognizers overview.
- `https://developer.apple.com/documentation/appkit/nsgesturerecognizer` — NSGestureRecognizer: base class for gesture recognition.
- `https://developer.apple.com/documentation/appkit/nsclickgesturerecognizer` — NSClickGestureRecognizer: mouse click gesture detection.
- `https://developer.apple.com/documentation/appkit/nspanngesturerecognizer` — NSPanGestureRecognizer: pan/drag gesture detection.
- `https://developer.apple.com/documentation/appkit/nspressgesturerecognizer` — NSPressGestureRecognizer: press-and-hold detection.
- `https://developer.apple.com/documentation/appkit/nsrotationgesturerecognizer` — NSRotationGestureRecognizer: two-touch rotation detection.
- `https://developer.apple.com/documentation/appkit/nsmagnificationgesturerecognizer` — NSMagnificationGestureRecognizer: pinch magnification detection.

## Drag & Drop

- `https://developer.apple.com/documentation/appkit/drag-and-drop` — Drag and drop overview: sources, destinations, sessions.
- `https://developer.apple.com/documentation/appkit/nsdraggingsource` — NSDraggingSource: protocol for drag source objects.
- `https://developer.apple.com/documentation/appkit/nsdraggingdestination` — NSDraggingDestination: protocol for drop target objects.
- `https://developer.apple.com/documentation/appkit/nsdraggingsession` — NSDraggingSession: in-progress drag operation management.
- `https://developer.apple.com/documentation/appkit/nsdraggingitem` — NSDraggingItem: single dragged item within a session.
- `https://developer.apple.com/documentation/appkit/nsdragginginfo` — NSDraggingInfo: dragging session information protocol.
- `https://developer.apple.com/documentation/appkit/nsfilepromiseprovider` — NSFilePromiseProvider: pasteboard file promise for drag and drop.
- `https://developer.apple.com/documentation/appkit/supporting-drag-and-drop-through-file-promises` — Guide: file promise drag and drop.

## Layout

- `https://developer.apple.com/documentation/appkit/view-layout` — View layout: NSStackView and Auto Layout constraints.
- `https://developer.apple.com/documentation/appkit/nslayoutconstraint` — NSLayoutConstraint: constraint relationship between UI objects.
- `https://developer.apple.com/documentation/appkit/nslayoutanchor` — NSLayoutAnchor: fluent constraint creation API.
- `https://developer.apple.com/documentation/appkit/nslayoutguide` — NSLayoutGuide: rectangular area for Auto Layout.
- `https://developer.apple.com/documentation/appkit/nslayoutdimension` — NSLayoutDimension: size-based constraint factory.

## Color

- `https://developer.apple.com/documentation/appkit/color` — Color management: NSColor, NSColorSpace, color pickers.
- `https://developer.apple.com/documentation/appkit/nscolor` — NSColor: color data with opacity, named system colors, dynamic colors.
- `https://developer.apple.com/documentation/appkit/nscolorspace` — NSColorSpace: custom color space representation.
- `https://developer.apple.com/documentation/appkit/nscolorwell` — NSColorWell: color selection control.
- `https://developer.apple.com/documentation/appkit/nscolorpanel` — NSColorPanel: system color picker panel.
- `https://developer.apple.com/documentation/appkit/nscolorsampler` — NSColorSampler: system color-sampling interface.

## Images

- `https://developer.apple.com/documentation/appkit/images-and-pdf` — Images and PDF: NSImage, bitmap/vector formats.
- `https://developer.apple.com/documentation/appkit/nsimage` — NSImage: high-level image loading, drawing, and manipulation.
- `https://developer.apple.com/documentation/appkit/nsbitmapimagerep` — NSBitmapImageRep: bitmap data rendering, TIFF conversion.
- `https://developer.apple.com/documentation/appkit/nsimagerep` — NSImageRep: semiabstract image representation superclass.
- `https://developer.apple.com/documentation/appkit/nspdfimagerep` — NSPDFImageRep: PDF format image rendering.

## Text Display

- `https://developer.apple.com/documentation/appkit/text-display` — Text display: NSTextView, NSTextField, spell checking.
- `https://developer.apple.com/documentation/appkit/nstextview` — NSTextView: rich text display and editing, spell checking integration.
- `https://developer.apple.com/documentation/appkit/nstextviewdelegate` — NSTextViewDelegate: selection, text attributes, spell check callbacks.
- `https://developer.apple.com/documentation/appkit/nstextfielddelegate` — NSTextFieldDelegate: field editor action menu control.
- `https://developer.apple.com/documentation/appkit/textkit` — TextKit: programmatic text storage and layout.
- `https://developer.apple.com/documentation/appkit/nsspellchecker` — NSSpellChecker: spell-checking service interface.
- `https://developer.apple.com/documentation/appkit/nstextinputcontext` — NSTextInputContext: text input system integration.
- `https://developer.apple.com/documentation/appkit/writing-tools` — Writing Tools: system writing assistance in text views.

## Pasteboard

- `https://developer.apple.com/documentation/appkit/documents-data-and-pasteboard` — Documents, data, pasteboard overview.
- `https://developer.apple.com/documentation/appkit/nspasteboard` — NSPasteboard: system pasteboard server access, read/write.
- `https://developer.apple.com/documentation/appkit/nspasteboarditem` — NSPasteboardItem: individual item on a pasteboard.

## Appearance

- `https://developer.apple.com/documentation/appkit/appearance-customization` — Dark Mode and appearance customization.
- `https://developer.apple.com/documentation/appkit/nsappearance` — NSAppearance: standard appearance themes for UI elements.

## Accessibility

- `https://developer.apple.com/documentation/appkit/accessibility-for-appkit` — Accessibility overview: built-in support and customization.
- `https://developer.apple.com/documentation/appkit/nsaccessibilityprotocol` — NSAccessibilityProtocol: all properties and methods for accessible elements.
- `https://developer.apple.com/documentation/appkit/nsaccessibilityelement-swift.class` — NSAccessibilityElement: base class for custom accessible elements.
- `https://developer.apple.com/documentation/appkit/custom-controls` — Custom controls: adopting role-specific accessibility protocols.

## Animation

- `https://developer.apple.com/documentation/appkit/animation` — Animation overview: view-based, custom, system animations.
- `https://developer.apple.com/documentation/appkit/nsanimationcontext` — NSAnimationContext: animation environment and state.
- `https://developer.apple.com/documentation/appkit/nsviewanimation` — NSViewAnimation: frame location/size and fade animations.
- `https://developer.apple.com/documentation/appkit/nsanimation` — NSAnimation: custom animation timing and progress.
- `https://developer.apple.com/documentation/appkit/nsshowanimationeffect` — NSShowAnimationEffect: run system animation effects.

## Sound & Haptics

- `https://developer.apple.com/documentation/appkit/sound-speech-and-haptics` — Sound, speech synthesis, haptic feedback overview.
- `https://developer.apple.com/documentation/appkit/nssound` — NSSound: simple audio file loading and playback.
- `https://developer.apple.com/documentation/appkit/nshapticfeedbackmanager` — NSHapticFeedbackManager: Force Touch trackpad haptic feedback.

## Cocoa Bindings

- `https://developer.apple.com/documentation/appkit/cocoa-bindings` — Cocoa Bindings: auto-sync data model with interface.
- `https://developer.apple.com/documentation/appkit/nsobjectcontroller` — NSObjectController: bindings-compatible key-value controller.
- `https://developer.apple.com/documentation/appkit/nsarraycontroller` — NSArrayController: bindings-compatible collection controller.
- `https://developer.apple.com/documentation/appkit/nsuserdefaultscontroller` — NSUserDefaultsController: preference binding controller.

## Resource Management

- `https://developer.apple.com/documentation/appkit/resource-management` — Storyboards and nib files: loading and management.
- `https://developer.apple.com/documentation/appkit/nsstoryboard` — NSStoryboard: Interface Builder storyboard resource encapsulation.
- `https://developer.apple.com/documentation/appkit/nsnib` — NSNib: Interface Builder nib file wrapper.

## Drawing

- `https://developer.apple.com/documentation/appkit/drawing` — Drawing overview: contexts, shapes, gradients, shadows.
- `https://developer.apple.com/documentation/appkit/nsgraphicscontext` — NSGraphicsContext: graphics rendering context.
- `https://developer.apple.com/documentation/appkit/nsbezierpath` — NSBezierPath: PostScript-style path creation.
- `https://developer.apple.com/documentation/appkit/nsgradient` — NSGradient: gradient fill drawing.
- `https://developer.apple.com/documentation/appkit/nsshadow` — NSShadow: drop shadow attributes during drawing.

## AppKit—SwiftUI Bridging

- `https://developer.apple.com/documentation/swiftui/appkit-integration` — SwiftUI ↔ AppKit bridging: hosting, representables, controllers.
- `https://developer.apple.com/documentation/swiftui/nsviewrepresentable` — NSViewRepresentable: wrap AppKit views for SwiftUI hierarchies.
- `https://developer.apple.com/documentation/swiftui/nshostingcontroller` — NSHostingController: AppKit view controller hosting SwiftUI views.
- `https://developer.apple.com/documentation/swiftui/nshostingview` — NSHostingView: AppKit view hosting SwiftUI view hierarchies.

## Documents

- `https://developer.apple.com/documentation/appkit/nsdocument` — NSDocument: abstract interface for macOS documents.
- `https://developer.apple.com/documentation/appkit/nsdocumentcontroller` — NSDocumentController: app's document management.
- `https://developer.apple.com/documentation/appkit/nspersistentdocument` — NSPersistentDocument: Core Data integrated document.
