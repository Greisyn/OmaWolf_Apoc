# Werewolf Sheet — floating Omarchy plugin

Corner-anchored WTA20 character sheet editor, in the style of
`io.github.i12bp8.oshelf` / `local.cliamp-dock`.

## Install
```bash
omarchy plugin add https://github.com/Greisyn/OmaWolf_Apoc.git --enable
```

- **Edit like the PDF**: identity header, Attributes, Talents/Skills/Knowledges,
  Renown/pools, Gifts/Backgrounds/notes.
- **Export plain text for LLM roleplay**: same format as
  `~/Pictures/werewolf_sheet.py` (`WEREWOLF: THE APOCALYPSE 20th - CHARACTER SHEET`).
- **Floating + corner-anchored**: dwell the corner handle to reveal,
  leave to collapse, pin open, Esc closes. Corner (TL/TR/BL/BR) + size in settings.
- **Output path is configurable**: settings panel + sheet footer. Default:
  `~/Pictures/<Name>.txt` (one file per character)
- **Theme-aware**: all chrome uses `Color.*` / `Style.*` — omarchy themes repaint it live.
- **Floating W anchor (drives-style)**: small always-visible square in a screen
  corner showing your transparent `icon.png` — hover-dwell or tap reveals the
  sheet, leaving collapses it. Toggleable (off = bar icon only), resizable.
- **Drag to move, snap to lock**: click-hold the square and drag it anywhere on
  the workspace; drop near a corner to snap/lock it there, else it floats free
  (card opens beside it). Settings has a lock switch to disable dragging, and
  corner buttons to snap it back. Placement persists in the prefs JSON.
- **Logo**: transparent `W20Logo-1024x369.png` from `~/Pictures` at the top of
  the card and settings panel (`logo.png`); W icon as anchor + bar symbol
  (`anchor-icon.png`, from `~/Pictures/icon.png`). To swap art later, replace
  those two files and run `omarchy-shell shell rescanPlugins`.

## Files

- `manifest.json` — service + bar-widget
- `SheetService.qml` — character data, JSON persistence, export, per-screen windows, IPC
- `SheetWindow.qml` — floating editor card (logo-only header, icon pin/close actions)
- `SheetGlyph.qml` / `SheetAction.qml` — theme-aware line-icon buttons (pin/close/check style)
- `SheetConfig.qml` — corner/size/motion/output prefs → `~/.config/omarchy/local.werewolf-sheet.json`
- `Sheet.js` — field lists + plain-text renderer
- `BarWidget.qml` — bar icon (left = toggle, right = settings)
- `Panel.qml` — settings (anchor square, corner, size, output path, motion)
- `logo.png` — Werewolf 20th logo from the PDF
- `anchor-icon.png` — W icon for the floating square + bar (`~/Pictures/icon.png`)

## Actions

- **Export .txt / Copy for LLM** — filled buttons in the card's CHARACTER FILE
  section; exports save as `<Name>.txt` inside the configured output folder so
  each character gets its own file (e.g. `Mara-Breaks-the-Chain-Kovac.txt`).
  Every text row has a ✓ Set button that commits exactly what's visible, and
  Export/Copy auto-commit all fields first — typed text is never lost even if
  you never tabbed out of the field.
- **Import** — paste the path of an exported sheet and press Import to load it
  back (same format `werewolf_sheet.py` uses; legacy `Nature / Demeanor` lines
  understood). Also via `omarchy-shell local.werewolf-sheet importSheet`
  (uses the settings' import path).
- **Clear…** — asks “Clear the entire sheet? …” via a confirmation dialog, then
  resets to a true blank sheet: empty fields, Attributes 1 (WTA20 minimum),
  all Abilities and pools 0.
- **Scrolling** — mouse wheel / touchpad, drag the always-on scrollbar,
  or PageUp / PageDown when the card is focused.

## Note: developing this plugin

Hot-reload (`shell rescanPlugins` / file watcher) reliably picks up
`SheetWindow.qml` / `Panel.qml` / `BarWidget.qml` changes, but does **not**
reliably re-create the long-running `SheetService` — after editing
`SheetService.qml` (or `Sheet.js` behavior), run:

```bash
omarchy restart shell
```

## State

- Character JSON: `~/.config/omarchy/local.werewolf-sheet-character.json`
- Prefs JSON: `~/.config/omarchy/local.werewolf-sheet.json`
- Export default: `~/Pictures/<Name>.txt` (one file per character)

## Commands

```bash
omarchy-shell local.werewolf-sheet show
omarchy-shell local.werewolf-sheet hide
omarchy-shell local.werewolf-sheet toggle
omarchy-shell local.werewolf-sheet exportSheet
omarchy-shell local.werewolf-sheet status
omarchy-shell shell rescanPlugins
omarchy restart shell
```

## Uninstall
```bash
omarchy plugin remove local.werewolf-sheet
```
