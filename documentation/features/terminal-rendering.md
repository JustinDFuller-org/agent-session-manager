# Terminal Rendering

## What

Agent Session Manager uses SwiftTerm for terminal emulation. A fork of SwiftTerm is used with a fix that ensures blank/empty cells in the terminal buffer contain space characters (U+0020) instead of null characters (U+0000).

## Why

SwiftTerm's default buffer initialization creates blank lines with cells containing the null character (code 0). When scrolling through terminal history, these null characters appear as `^@` (caret notation for NUL) in debug log output.

## Fix

### SwiftTerm fork

The fork of SwiftTerm (at `https://github.com/JustinDFuller/SwiftTerm`, branch `fix/blank-line-null-cells`) changes `Buffer.getBlankLine()` to use `getNullCell(attribute:)` instead of `CharData(attribute:)`. The `getNullCell` method creates cells with space characters (code 32), matching the expected behavior for blank terminal cells.

### `renderedScreenText` null → space replacement

`TerminalController.renderedScreenText` replaces any remaining null cells (code 0) with space characters before building the output string. This matches SwiftTerm's own visual renderer (`buildAttributedString` in `AppleTerminalView`) which does the same: `ch.code == 0 ? " " : terminal.getCharacter(for: ch)`.

Replacing with spaces (rather than filtering them out) preserves the layout of multi-column terminal output in the debug log. For example, Claude Code's todo table — where columns are separated by null cells — renders as `"Files     Modified"` rather than collapsing to `"FilesModified"`.

Trailing spaces are trimmed per line, and fully-blank lines are removed from the output, so all-null rows still produce empty strings.

## How to verify

1. Enable debug logging in Settings > Debug
2. Open the Debug Log window and click "Capture Terminal"
3. Verify the terminal content shows clean text without `^@` characters
4. For multi-column output (e.g. Claude's task list), verify column spacing is preserved

## Updating SwiftTerm

When updating to a newer version of SwiftTerm, the fix must be re-applied or upstreamed:

Edit `Buffer.getBlankLine()`:

```swift
// Before:
let cd = CharData(attribute: attribute)
// After:
let cd = getNullCell(attribute: attribute)
```
