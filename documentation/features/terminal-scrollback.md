# Terminal Scrollback History

## What It Is

The terminal scrollback buffer stores lines of output that have scrolled off the visible area. A larger buffer lets you scroll back further to review earlier output — useful for long agent runs that produce extensive output.

## Default

The default scrollback is **500 lines**, matching SwiftTerm's built-in default.

## Valid Range

100 – 1,000,000 lines. Values outside this range are clamped automatically.

## How to Change

1. Open **Settings → General → Terminal**.
2. Edit the **Scrollback Lines** field.
3. The new value takes effect immediately in every open terminal pane — no restart required.
4. The setting persists across app launches.
