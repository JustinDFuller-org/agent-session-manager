---
name: swifterm-documentation
description: SwiftTerm official doc index — load when building SwiftTerm features, terminal emulation, terminal views, process lifecycle, delegate callbacks, GPU rendering, pseudo-terminals, or any SwiftTerm-specific behavior. Any project that uses or interacts with SwiftTerm should load this skill.
user-invocable: false
allowed-tools:
  - WebFetch(domain:migueldeicaza.github.io)
---

# SwiftTerm Documentation Index

Fetch from this index before implementing any terminal feature — do not guess at behavior. One URL per topic — read the most specific one first.

## Discovery

- `https://migueldeicaza.github.io/SwiftTerm/documentation/swiftterm/` — Main framework overview; VT100/Xterm terminal emulator library for Swift (macOS, iOS, visionOS, Linux).
- `https://github.com/migueldeicaza/SwiftTerm` — GitHub repository with README, sample apps (`TerminalApp/`), and full source code.

## Getting Started

- `https://migueldeicaza.github.io/SwiftTerm/documentation/swiftterm/gettingstarted` — Step-by-step guide: adding SwiftTerm via SPM, embedding on macOS/iOS/visionOS, headless setup, platform availability matrix.

## Core Engine

- `https://migueldeicaza.github.io/SwiftTerm/documentation/swiftterm/terminal` — Terminal class: VT100/Xterm emulation engine; feeds data, manages terminal state, buffer kind, mouse mode. Thread-safe.
- `https://migueldeicaza.github.io/SwiftTerm/documentation/swiftterm/terminaloptions` — TerminalOptions struct: startup configuration (colors, scrollback, cursor, font, resize behavior).
- `https://migueldeicaza.github.io/SwiftTerm/documentation/swiftterm/cursorstyle` — CursorStyle enum: block, underline, bar cursor shapes; blinking configuration; application cursor override.

## Delegate Protocols

- `https://migueldeicaza.github.io/SwiftTerm/documentation/swiftterm/terminaldelegate` — TerminalDelegate protocol: engine-to-UI notifications (terminal resize, scroll, bell, title change, cursor visibility).

## Platform Views

- `https://migueldeicaza.github.io/SwiftTerm/documentation/swiftterm/terminalview` — TerminalView class: AppKit NSView (macOS) and UIKit UIScrollView (iOS/visionOS) front-end for Terminal. GPU renderer, font, colors, link handling, selection.
- `https://migueldeicaza.github.io/SwiftTerm/documentation/swiftterm/terminalviewdelegate` — TerminalViewDelegate protocol: send user input, open links, clipboard, scroll position, selection range changes.

## Local Processes

- `https://migueldeicaza.github.io/SwiftTerm/documentation/swiftterm/localprocess` — LocalProcess class: launch a Unix process inside a pseudo-terminal; stdin/stdout/stderr lifecycle.
- `https://migueldeicaza.github.io/SwiftTerm/documentation/swiftterm/localprocessdelegate` — LocalProcessDelegate protocol: data received from process, process termination, window size requests.
- `https://migueldeicaza.github.io/SwiftTerm/documentation/swiftterm/localprocessterminalview` — LocalProcessTerminalView class: AppKit NSView that connects TerminalView to a local process via pseudo-terminal. macOS-only. Requires disabling sandbox.
- `https://migueldeicaza.github.io/SwiftTerm/documentation/swiftterm/localprocessterminalviewdelegate` — LocalProcessTerminalViewDelegate protocol: process lifecycle notifications re-posted from TerminalViewDelegate (title, size, termination, CWD).

## Local Process Key Methods

- `https://migueldeicaza.github.io/SwiftTerm/documentation/swiftterm/localprocessterminalview/startprocess(executable:args:environment:execname:currentdirectory:)` — startProcess: launch an executable in the pseudo-terminal with custom args, env, and working directory.
- `https://migueldeicaza.github.io/SwiftTerm/documentation/swiftterm/localprocessterminalview/terminate()` — terminate(): kill the running pseudo-terminal process.
- `https://migueldeicaza.github.io/SwiftTerm/documentation/swiftterm/localprocessterminalview/processdelegate` — processDelegate property: set to receive LocalProcessTerminalViewDelegate callbacks.

## TerminalView Key Methods

- `https://migueldeicaza.github.io/SwiftTerm/documentation/swiftterm/terminalview/feed(bytearray:)` — feed(byteArray:): send byte data to the terminal emulator for interpretation. Thread-safe.
- `https://migueldeicaza.github.io/SwiftTerm/documentation/swiftterm/terminalviewdelegate/send(source:data:)` — send(source:data:): delegate method — forward user keystrokes to the backend process.
- `https://migueldeicaza.github.io/SwiftTerm/documentation/swiftterm/terminalviewdelegate/requestopenlink(source:link:params:)` — requestOpenLink: delegate callback when user activates an OSC 8 hyperlink or auto-detected URL.

## Headless Terminal

- `https://migueldeicaza.github.io/SwiftTerm/documentation/swiftterm/headlessusage` — Headless Terminal Usage article: run terminal without UI for scripting, testing, automation, screen scraping.
- `https://migueldeicaza.github.io/SwiftTerm/documentation/swiftterm/headlessterminal` — HeadlessTerminal class: terminal emulator + local process with no display; access buffer programmatically.

## Guides

- `https://migueldeicaza.github.io/SwiftTerm/documentation/swiftterm/customization` — Customizing the Terminal: fonts (monospaced, fallback), colors, cursor style, keyboard input behavior.
- `https://migueldeicaza.github.io/SwiftTerm/documentation/swiftterm/gpurendering` — GPU-Accelerated Rendering: enabling/disabling Metal renderer, buffering modes, error handling, supported features, SWIFTTERM_METAL_LIVE_RESIZE_THROTTLE env var.
- `https://migueldeicaza.github.io/SwiftTerm/documentation/swiftterm/graphicssupport` — Graphics Support: Sixel, iTerm2 inline images, and Kitty graphics protocol rendering.
- `https://migueldeicaza.github.io/SwiftTerm/documentation/swiftterm/sshintegration` — Connecting via SSH: wire a TerminalView to a remote host (uses swift-nio-ssh reference).

## Buffer & Content Access

- `https://migueldeicaza.github.io/SwiftTerm/documentation/swiftterm/buffer` — Buffer class: terminal screen content storage; rows, cells, scrolling.
- `https://migueldeicaza.github.io/SwiftTerm/documentation/swiftterm/bufferline` — BufferLine class: a single line of terminal cells; character data per column.
- `https://migueldeicaza.github.io/SwiftTerm/documentation/swiftterm/terminal/bufferkind` — Terminal.BufferKind enum: primary screen buffer vs alternate screen buffer.

## Data Types

- `https://migueldeicaza.github.io/SwiftTerm/documentation/swiftterm/attribute` — Attribute struct: per-cell foreground/background Color and CharacterStyle.
- `https://migueldeicaza.github.io/SwiftTerm/documentation/swiftterm/chardata` — CharData struct: cell character with full grapheme cluster support (stores Int32 with parallel index lookup for multi-scalar clusters).
- `https://migueldeicaza.github.io/SwiftTerm/documentation/swiftterm/characterstyle` — CharacterStyle struct: bold, italic, underline, strikethrough, dim/faint, blink, inverse, invisible cell decorations.
- `https://migueldeicaza.github.io/SwiftTerm/documentation/swiftterm/color` — Color class: 16-bit RGB terminal colors supporting ANSI, 256-color palette, and TrueColor.
- `https://migueldeicaza.github.io/SwiftTerm/documentation/swiftterm/position` — Position struct: column and row coordinates.

## Selection & Search

- `https://migueldeicaza.github.io/SwiftTerm/documentation/swiftterm/searchoptions` — SearchOptions struct: configure terminal text search (case sensitivity, regex, direction).

## GPU Rendering

- `https://migueldeicaza.github.io/SwiftTerm/documentation/swiftterm/terminalview/setusemetal(_:)` — setUseMetal(_:): enable/disable Metal GPU-accelerated rendering; throws MetalError on failure.
- `https://migueldeicaza.github.io/SwiftTerm/documentation/swiftterm/terminalview/metalbufferingmode` — metalBufferingMode property: choose per-row persistent or per-frame aggregated GPU buffer strategy.
- `https://migueldeicaza.github.io/SwiftTerm/documentation/swiftterm/terminalview/isusingmetalrenderer` — isUsingMetalRenderer: check whether Metal renderer is currently active.
- `https://migueldeicaza.github.io/SwiftTerm/documentation/swiftterm/metalbufferingmode` — MetalBufferingMode enum: perRowPersistent (interactive shells) vs perFrameAggregated (full-screen TUI apps).
- `https://migueldeicaza.github.io/SwiftTerm/documentation/swiftterm/metalerror` — MetalError enum: deviceUnavailable (no Metal GPU), shaderCompilationFailed (build issue).

## Graphics

- `https://migueldeicaza.github.io/SwiftTerm/documentation/swiftterm/imagesizerequest` — ImageSizeRequest enum: configure width/height for inline terminal images.
- `https://migueldeicaza.github.io/SwiftTerm/documentation/swiftterm/terminalimage` — TerminalImage protocol: represent inline images in terminal cells (Sixel, iTerm2, Kitty).

## Mouse Input

- `https://migueldeicaza.github.io/SwiftTerm/documentation/swiftterm/terminal/mousemode-swift.enum` — Terminal.MouseMode enum: mouse event reporting protocols (none, X10, SGR, UTF-8, URxvt, button event, any event).

## Link Handling

- `https://migueldeicaza.github.io/SwiftTerm/documentation/swiftterm/linkhighlightmode` — LinkHighlightMode enum: how links are highlighted and activated (none, hover, hoverWithModifier, tap, modifierTap).
- `https://migueldeicaza.github.io/SwiftTerm/documentation/swiftterm/linkreporting` — LinkReporting enum: link discovery modes (none, explicit OSC 8 only, implicit URL detection from text).

## Escape Sequence Parsing

- `https://migueldeicaza.github.io/SwiftTerm/documentation/swiftterm/escapesequenceparser` — EscapeSequenceParser class: VT100/Xterm escape and control sequence parsing engine.
- `https://migueldeicaza.github.io/SwiftTerm/documentation/swiftterm/escapesequences` — EscapeSequences struct: common escape sequence response strings (cursor keys, mode switches, device attributes).

## Pseudoterminal Helpers

- `https://migueldeicaza.github.io/SwiftTerm/documentation/swiftterm/pseudoterminalhelpers` — PseudoTerminalHelpers class: Unix pseudo-terminal control APIs (openpty, window size, I/O).

## Kitty Keyboard Protocol

- `https://migueldeicaza.github.io/SwiftTerm/documentation/swiftterm/kittykeyboardflags` — KittyKeyboardFlags struct: Kitty keyboard protocol flag bits.
- `https://migueldeicaza.github.io/SwiftTerm/documentation/swiftterm/kittykeyboardmodifiers` — KittyKeyboardModifiers struct: modifier key state for Kitty keyboard events.
- `https://migueldeicaza.github.io/SwiftTerm/documentation/swiftterm/kittykeyboardeventtype` — KittyKeyboardEventType enum: press, repeat, release key event types.

## Image Cells

- `https://migueldeicaza.github.io/SwiftTerm/documentation/swiftterm/imagecell` — ImageCell class: attach images to terminal cells; used by Sixel, iTerm2, and Kitty graphics.

## Additional Types

- `https://migueldeicaza.github.io/SwiftTerm/documentation/swiftterm/tinyatom` — TinyAtom struct: 16-bit string atom for OSC 8 hyperlink URLs and inline image binary blobs.
- `https://migueldeicaza.github.io/SwiftTerm/documentation/swiftterm/ttimage` — TTImage typealias: platform image type (NSImage on macOS, UIImage on iOS/visionOS).

## Additional Enumerations

- `https://migueldeicaza.github.io/SwiftTerm/documentation/swiftterm/ansi256palettestrategy` — Ansi256PaletteStrategy enum: strategy for deriving 256-color palette from first 16 ANSI colors.
- `https://migueldeicaza.github.io/SwiftTerm/documentation/swiftterm/regionalindicatorwidth` — RegionalIndicatorWidth enum: width assigned to unpaired flag emoji characters; combined pairs always width 2.
- `https://migueldeicaza.github.io/SwiftTerm/documentation/swiftterm/underlinestyle` — UnderlineStyle enum: single, double, curly, dotted, dashed underline text decorations.

## Debug & Inspection

- `https://migueldeicaza.github.io/SwiftTerm/documentation/swiftterm/terminaldebugview` — TerminalDebugView class: debug overlay on TermKit for inspecting terminal state.

## Platform Extensions

- `https://migueldeicaza.github.io/SwiftTerm/documentation/swiftterm/appkit` — AppKit module: macOS-specific TerminalView extensions and NSView integration.
