# Tab Loading Indicator

> **Superseded.** The green loading dot and orange/accent notification dot were replaced by `ActivityIndicatorView` in the tab-pane-activity-indicators feature. See [`tab-pane-activity-indicators.md`]({{ '/documentation/features/tab-pane-activity-indicators/' | relative_url }}) for current behavior.

## Historical behavior (pre-supersession)

A small green pulsing dot appeared in the tab bar when any pane in the tab had a running process (`Tab.hasRunningPane`). A separate orange/accent dot appeared when a pending notification existed. Both have been replaced by a single tri-state indicator (idle ring / working dot / waiting dot) that answers the question: where should I focus my attention right now?
