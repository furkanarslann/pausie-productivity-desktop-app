# Pausie

macOS menu bar break app (Swift 6, SwiftUI + AppKit, macOS 14+). Build, test and project layout: [README.md](README.md).

## Keep the docs in step with the code

When a change adds or changes behavior the user can see (a state, transition, rule, screen, button,
timing or text), update the docs **in the same commit**:

- **[docs/FLOW.md](docs/FLOW.md)**: make it describe the app as built after the change.
- **[docs/DECISIONS.md](docs/DECISIONS.md)**: add an entry when the change differs from the spec, the
  guide or Figma, or reverses an earlier decision. Use the next number, the date, who asked for it, why,
  what it supersedes and the commit. Never delete old entries; mark the replaced one as superseded.
- If the change alters behavior described in the *Pausie MVP Spec* doc, offer to update it too.

Refactors, fixes and tests that don't change behavior need no doc change.

## Rules

- Behavior lives in `SessionMachine` (a pure reducer); every transition has a test in `SessionMachineTests`.
- No hardcoded text, colors, fonts or sizes: use `en.json` + `L10nKey`, `ColorToken`, `TypographyToken`, `Metrics`.
- Run the tests before committing (`xcodebuild … test`, see README).
- Commits here use the personal GitHub identity set in this repo's local git config. Never change the
  global git config.
