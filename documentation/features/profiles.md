# Profiles

Profiles let you save a named harness type, harness-specific CLI flags, supported environment variables, and (optionally) a custom status line configuration. When you create a new pane, selecting a profile pre-fills the applicable settings automatically.

## Creating a Profile

Open **Settings → Profiles** and click **+**. You can also click **Save Profile & Create** in the New Pane sheet to snapshot the current form as a new profile.

## Editing a Profile

In **Settings → Profiles**, select a profile and click **Edit**. Every available CLI flag for the selected harness is shown. Claude Code and OpenCode profiles also show their environment-variable catalogs. For each option you can:

- **Enable/disable** the option (the checkbox on the left) — controls whether the flag or environment variable is passed when the pane starts.
- **Set a value** — for string flags like `--model`, type the value in the text field.
- **Show on create** — tick the **Show** checkbox on the right to make the option visible in the New Pane sheet whenever this profile is selected (see below).

## Show on Create

By default, when a profile is selected in the New Pane sheet, no individual options are shown. All options stored in the profile are still applied — they are just hidden so the sheet stays clean.

Marking an option **Show** means it will appear as an editable toggle or text field in the New Pane sheet. This is useful for options you want to decide on per-pane, like `--continue` or `--resume`, while keeping fixed options like `--model` or `ANTHROPIC_API_KEY` out of the way.

Options hidden from the New Pane sheet are still passed to the selected harness exactly as configured in the profile.

## Applying a Profile

In the New Pane sheet, choose a profile from the **Profile** picker. The harness is locked to the profile's harness. Only options marked **Show** in the profile are displayed. All other profile options are applied silently.

If you change any option while a profile is selected, the picker label updates to show **(modified)**. You can click **Save Profile & Create** to save the modified form as a new or updated profile before creating the pane.

## Profile Ordering

Profiles appear in the order defined in **Settings → Profiles**. Use the up/down arrows to reorder them. The first profile that matches the active harness is pre-selected when the New Pane sheet opens.
