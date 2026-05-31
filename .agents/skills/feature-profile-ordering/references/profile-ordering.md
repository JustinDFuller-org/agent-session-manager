# Profile Ordering

Profiles in Agent Session Manager can be ranked by preference. The order in which profiles appear in Settings determines which one is pre-selected when you open the New Pane sheet.

## What is profile ranking?

Every profile has a position in the list. The profile at the top is your highest-ranked (most preferred) profile. When you open the New Pane sheet, the app automatically selects the first profile in the list that matches the active CLI tool — so the right profile is ready without any manual picking.

## How to reorder profiles

Open **Settings → Profiles**. Each profile row shows two chevron buttons on the right side:

- **↑ (chevron.up)** — moves the profile up one position (disabled when the profile is already at the top)
- **↓ (chevron.down)** — moves the profile down one position (disabled when the profile is already at the bottom)

Click either button to swap the profile with its neighbor. The new order is saved immediately.

## How ranking affects New Pane pre-selection

When you open the New Pane sheet, the profile picker pre-selects the first profile in ranked order whose harness matches the active tool. For example, if your profiles in order are:

1. Fast Claude (claude)
2. Deep Work (claude)
3. Codex Default (codex)

…and the active tool is Claude, the picker will pre-select **Fast Claude** automatically.

If no profile matches the active tool, no profile is pre-selected and you can pick one manually or proceed without a profile.

## Note on the old "Set as Default" concept

Previous versions had a star button to designate one profile as the default, separate from its list position. This concept has been replaced by position: the top-ranked matching profile is always the default. There is no longer a separate "Set as Default" action.
