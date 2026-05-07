# Terminal Rendering

## What

Agent Session Manager uses SwiftTerm for terminal emulation. A fork of SwiftTerm is used with a fix that ensures blank/empty cells in the terminal buffer contain space characters (U+0020) instead of null characters (U+0000).

## Why

SwiftTerm's default buffer initialization creates blank lines with cells containing the null character (code 0). When scrolling through terminal history, these null characters appear as `^@` (caret notation for NUL) in debug log output and as visual gaps in the terminal display.

## Fix

The fork of SwiftTerm (at `https://github.com/JustinDFuller/SwiftTerm`, branch `fix/blank-line-null-cells`) changes `Buffer.getBlankLine()` to use `getNullCell(attribute:)` instead of `CharData(attribute:)`. The `getNullCell` method creates cells with space characters (code 32), matching the expected behavior for blank terminal cells.

Additionally, `TerminalController.terminalContent` filters any remaining null characters from its output to ensure accurate debug log capture.

## How to verify

1. Enable debug logging in Settings > Debug
2. Open the Debug Log window and click "Capture Terminal"
3. Verify the terminal content shows clean text without `^@` characters

## Updating SwiftTerm

When updating to a newer version of SwiftTerm, the fix must be re-applied or upstreamed:

Edit `Buffer.getBlankLine()`:

```swift
// Before:
let cd = CharData(attribute: attribute)
// After:
let cd = getNullCell(attribute: attribute)
```
