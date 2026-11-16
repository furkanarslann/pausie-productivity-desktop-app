# Pausie

A macOS menu bar break app. Pausie counts the work session, asks you to note where you left off
5 min before the break, enforces the break with a dimmed screen, and gives your note back as a
markdown todo list when you return.

**Work (50 min) → note in the last 5 min ("Save", "Ask me later" or "Skip") → break (10 min) → "Let's go!" → see and copy the note → new cycle**

Built from the *Pausie MVP Spec* (behavior), the Figma file (visuals) and the *MVP Implementation
Guide* (structure). Where the app intentionally differs from them, the decision is recorded in
[docs/DECISIONS.md](docs/DECISIONS.md) and takes precedence; [docs/FLOW.md](docs/FLOW.md) describes the
behavior as built.

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

Every screen can be rendered offscreen in light and dark for comparison with Figma, at Retina (2x)
and at 1x (files ending in `-1x`, as on a 1080p monitor):

```bash
TEST_RUNNER_PAUSIE_SNAPSHOT_DIR=/tmp/pausie-snapshots xcodebuild -project Pausie.xcodeproj -scheme Pausie -derivedDataPath build/DerivedData test -only-testing:PausieTests/SnapshotTests
```

`ImageRenderer` can't draw AppKit-backed controls, so text fields in the note editors appear as
yellow placeholders in the PNGs; everything else renders as in the app.

### Window tests

Tests that open the real panels on screen (resume panel with long wrapped notes, note window growth,
settings) are opt-in because windows flash on screen while they run:

```bash
TEST_RUNNER_PAUSIE_WINDOW_TESTS=1 xcodebuild -project Pausie.xcodeproj -scheme Pausie -derivedDataPath build/DerivedData test -only-testing:PausieTests/WindowTests
```

Add `TEST_RUNNER_PAUSIE_REPRO_NOTES=/path/to/notes.json` to also open every note from a notes file.

## Project layout

| Folder | Contents |
| --- | --- |
| `Pausie/App` | `@main` app, `AppDelegate`, `AppCoordinator` (object graph, applies UI effects) |
| `Pausie/Core` | `SessionState` / `SessionEvent` / `SessionEffect`, the pure `SessionMachine` reducer (T1–T22), `SessionController` (timers, pause, sleep/lock, settings snapshot) |
| `Pausie/Data` | `Settings` + `SettingsStore` (UserDefaults), `BreakSound` (the sound catalog), `Note` + `TodoMarkdown`, `NoteStore` (last 5 notes in `~/Library/Application Support/Pausie/notes.json`) |
| `Pausie/System` | `SystemEvents` (sleep, wake, lock, displays), `ChimePlayer` (break-over sound and Settings previews) |
| `Pausie/UI` | Status item + menu, note window, break layer, resume panel, settings, shared components |
| `Pausie/Theme` | `ColorTokens` (Figma `Pausie` collection), `TypographyTokens`, `Metrics` (every size from Figma), `AppearanceController` |
| `Pausie/Localization` | `L10n` + `L10nKey`, `TimeFormat` (system-locale time formats) |
| `Pausie/Resources` | `Localization/en.json`, `Assets.xcassets` (poses, menu bar template, app icon), `Sounds/` (music written for Pausie, see [docs/SOUNDS.md](docs/SOUNDS.md)) |
| `Design/AppIcon` | Icon Composer source layers |
| `Tools/BreakMusic` | `compose.swift` writes and synthesizes the break-over music; `render.sh` rebuilds `Pausie/Resources/Sounds` (needs ffmpeg) |

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
   required-note editor, sleep/lock behavior, the break-over sounds.

## Flow and decisions

- [docs/FLOW.md](docs/FLOW.md): the behavior as built: states, transitions (T1–T22), rules, and what
  each screen and the menu show in every state.
- [docs/DECISIONS.md](docs/DECISIONS.md): every intentional difference from the spec, the guide and
  Figma, with date, who asked for it, why, and the commit.
- [docs/SOUNDS.md](docs/SOUNDS.md): where each bundled music clip comes from and its license.

When behavior changes, update FLOW.md and add a DECISIONS.md entry in the same commit.
