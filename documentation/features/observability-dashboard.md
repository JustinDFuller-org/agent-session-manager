# Observability Dashboard

Agent Session Manager includes an in-app trace dashboard that visualizes OpenTelemetry spans as a waterfall timeline, letting you see what the app is doing without leaving it.

## Enabling

1. Open **Settings → Tracing**.
2. Enable **Enable Tracing**.
3. Choose an output target (Stdout or File) — the in-memory buffer is always populated when tracing is on, regardless of target.

## Opening the Dashboard

Press **⌘⇧D** or use the menu **Window → Open Trace Dashboard**.

## Waterfall View

Each row represents one span. The bar's horizontal position and width show when the span started and how long it lasted. Zero-duration spans (instant events) appear as small circles.

Span bars are color-coded by name prefix:

| Prefix | Color |
|--------|-------|
| `terminal.*` | Accent (blue/purple) |
| `pane.*` | Blue |
| `tab.*` | Green |
| `pr.*` | Orange |
| `statusline.*` | Purple |
| other | Gray |

Click any row to select it and show its details in the panel below.

## Detail Panel

Shows the span name, trace ID, span ID, start time, duration, and all attributes as key=value rows. Text is selectable for copying.

## Filtering

Type in the **Filter** field in the toolbar to narrow spans by name.

## Buffer Size

The dashboard keeps the most recent spans in memory (default: 500). Older spans are dropped when the limit is reached. Adjust the limit under **Settings → Tracing → Dashboard Buffer**.
