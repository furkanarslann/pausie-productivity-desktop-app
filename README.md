# Pausie

A macOS menu bar break app. Pausie counts the work session, asks you to note where you left off
5 min before the break, enforces the break with a dimmed screen, and gives your note back as a
markdown todo list when you return.

**Work (50 min) → note in the last 5 min → break (10 min) → "Let's go!" → see and copy the note → new cycle**

Sources of truth: the *Pausie MVP Spec* (behavior), the Figma file (visuals), and the
*MVP Implementation Guide* (structure). If they disagree, the spec wins.

## Requirements

- macOS 14 Sonoma or later
- Xcode 26 (the project uses synchronized folders: new files under `Pausie/` and `PausieTests/` are picked up automatically)

## Build, run, test

Open `Pausie.xcodeproj` and run the **Pausie** scheme, or from the terminal:

```bash
xcodebuild -project Pausie.xcodeproj -scheme Pausie -derivedDataPath build/DerivedData build
```

```bash
open build/DerivedData/Build/Products/Debug/Pausie.app
```

```bash
xcodebuild -project Pausie.xcodeproj -scheme Pausie -derivedDataPath build/DerivedData test
```

Pausie has no Dock icon (`LSUIElement`); look for it in the menu bar. Builds are signed to run
locally; set your team in *Signing & Capabilities* if you want a stable signature.

### Visual snapshots

Every screen can be rendered offscreen in light and dark for comparison with Figma:

```bash
TEST_RUNNER_PAUSIE_SNAPSHOT_DIR=/tmp/pausie-snapshots xcodebuild -project Pausie.xcodeproj -scheme Pausie -derivedDataPath build/DerivedData test -only-testing:PausieTests/SnapshotTests
```

`ImageRenderer` can't draw AppKit-backed controls, so text fields in the note editors appear as
yellow placeholders in the PNGs; everything else renders as in the app.

## Project layout

| Folder | Contents |
| --- | --- |
| `Pausie/App` | `@main` app, `AppDelegate`, `AppCoordinator` (object graph, applies UI effects) |
| `Pausie/Core` | `SessionState` / `SessionEvent` / `SessionEffect`, the pure `SessionMachine` reducer (T1–T13), `SessionController` (timers, sleep/lock, settings snapshot) |
| `Pausie/Data` | `Settings` + `SettingsStore` (UserDefaults), `Note` + `TodoMarkdown`, `NoteStore` (last 5 notes in `~/Library/Application Support/Pausie/notes.json`) |
| `Pausie/System` | `SystemEvents` (sleep, wake, lock, displays), `ChimePlayer` |
| `Pausie/UI` | Status item + menu, note window, break layer, resume panel, settings, shared components |
| `Pausie/Theme` | `ColorTokens` (Figma `Pausie` collection), `TypographyTokens`, `Metrics` (every size from Figma), `AppearanceController` |
| `Pausie/Localization` | `L10n` + `L10nKey`, `TimeFormat` (system-locale time formats) |
| `Pausie/Resources` | `Localization/en.json`, `Assets.xcassets` (poses, menu bar template, app icon) |
| `Design/AppIcon` | Icon Composer source layers |

### Rules the code protects

- Views and window controllers make no decisions; they send events to `SessionController`, which asks
  `SessionMachine` and applies the returned effects. Every transition row is a unit test.
- No text, color or font is hardcoded in the UI: strings come from `en.json` through `L10nKey`,
  colors from `ColorToken`, fonts from `TypographyToken`, sizes from `Metrics`. Adding a language
  is a new `<lang>.json` with the same keys.

## Manual steps

1. **App icon (Icon Composer).** The project ships an interim `AppIcon.appiconset` made from the flat
   1024 px icon. To get the macOS 26 layered icon: open Icon Composer, add
   `Design/AppIcon/pausie-icon-background.png` as the background and `pausie-icon-foreground.png` as a
   layer, check light/dark/tinted, save as `AppIcon.icon` into `Pausie/Resources/`, then delete
   `Assets.xcassets/AppIcon.appiconset` (the target's App Icon name is already `AppIcon`).
2. **On-device checks** that can't be automated here: break layer over full-screen apps and on a
   second display, menu bar reachable during a break, typing into the note window and the
   required-note editor, sleep/lock behavior, the chime.

## Decisions taken from the guide's open points

The guide's proposals were used as defaults; change them here and in the spec if you decide otherwise.

| # | Question | Used |
| --- | --- | --- |
| 1 | Minimum macOS | 14 Sonoma |
| 2 | Break-over sound | System sound "Glass", every 10 s, stops at 60 s (`SoundToken`, `SessionRules`) |
| 3 | Launch at login | Not in the MVP |
| 4 | State after relaunch | `idle`; notes are kept |
| 5 | Apple logo on the Focused pose | Kept (personal use) |
| 6 | Distribution | Own Mac only; no notarization |

## Implementation notes and deviations

- **Menu chrome is native.** The status menu is an `NSMenu` (as the guide decides) with a SwiftUI
  status header, so the menu background and highlighted row use the system look rather than the
  custom Figma popover (radius 10, `brand/primary` highlight).
- **Note window (03b).** Centered on the main display, 600 pt wide, and it takes the keyboard when it
  opens so you can type right away (it's a non-activating panel, so Pausie doesn't come to the front).
  `⌘Return` saves (the primary button). The break note-required card (04) stays centered on the break layer.
- **Break ring (05).** The relaxed pose sits in a ring whose `brand/primary` arc shows the time left.
- **Note editor.** Each todo is its own line: Return adds a todo (not from an empty one), Backspace in an empty todo removes it
  (caret moves to the end of the one above), ↑/↓ move between todos. Empty todos are dropped on save
  wherever they are, so a cleared item never comes back as an empty checkbox.
- **"Welcome back!" panel closes itself after 15 s** (`SessionRules.resumePanelAutoCloseDelay`); the
  countdown pauses while the pointer is over it. The note stays in Recent notes. This replaces the
  spec's "stays until closed" (rule 8); it still also closes at the next warning.
- **T6/T7 also close the note window**, so an open "Edit note" window can't sit above the break.
- **Backdrop blur** under the 45% dim is an `NSVisualEffectView` at half strength, approximating
  Figma's 5 pt blur; tune `OpacityToken.breakBlur` after seeing it on screen.
- **Copy icon** uses the SF Symbol `doc.on.doc` tinted `brand/primary` (Figma's SVG keeps `#7C3AED`
  in dark).
- **Countdowns** are zero-padded `mm:ss` everywhere except the note window sentence
  ("Break starts in 4:52"), matching Figma. Clock times follow the system locale.
- **Steppers** move work time in 5 min steps (minimum 6 min, must be longer than the 5 min reminder
  lead) and break time in 1 min steps.
- Two strings were added beyond the guide's catalog: `menu.recentNotes.emptyNote` and
  `resume.emptyNote` (an empty note is a valid save), plus `menubar.accessibilityLabel`.
